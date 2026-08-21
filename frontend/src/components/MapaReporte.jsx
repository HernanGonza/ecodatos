// MapaReporte.jsx
// npm install react-leaflet-cluster

import { useEffect, useRef, useMemo, useState, useCallback } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap, ScaleControl } from "react-leaflet";
import MarkerClusterGroup from "react-leaflet-cluster";
import {
  Box, Text, Group, ThemeIcon, Badge, ActionIcon, Tooltip, SegmentedControl,
} from "@mantine/core";
import {
  IconMap2, IconMapPin, IconArrowsMaximize, IconArrowsMinimize,
} from "@tabler/icons-react";
import "leaflet/dist/leaflet.css";
import "leaflet.markercluster/dist/MarkerCluster.css";
import "leaflet.markercluster/dist/MarkerCluster.Default.css";
import L from "leaflet";

// ── Paleta ────────────────────────────────────────────────────────────────────
const PALETA = [
  "#22b8cf","#fab005","#12b886","#4c6ef5","#f06595",
  "#ae3ec9","#845ef7","#ff922b","#5c7cfa","#94d82d",
];
const TIPOS_NUM = new Set([
  "integer","bigint","numeric","real","double precision",
  "smallint","decimal","float","float4","float8","int2","int4","int8",
]);

// ── Pin 3D SVG — igual al estilo de Leaflet demo ─────────────────────────────
function makePinIcon(color) {
  const id = color.replace('#','');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 42" width="32" height="42">
    <defs>
      <linearGradient id="g${id}" x1="30%" y1="0%" x2="70%" y2="100%">
        <stop offset="0%" stop-color="#fff" stop-opacity="0.2"/>
        <stop offset="100%" stop-color="#000" stop-opacity="0.15"/>
      </linearGradient>
      <filter id="sh${id}" x="-30%" y="-10%" width="160%" height="150%">
        <feDropShadow dx="0" dy="2" stdDeviation="2.5" flood-color="rgba(0,0,0,0.45)"/>
      </filter>
    </defs>
    <path d="M16 2C9.4 2 4 7.4 4 14c0 9.3 12 26 12 26s12-16.7 12-26C28 7.4 22.6 2 16 2z"
      fill="${color}" filter="url(#sh${id})"/>
    <path d="M16 2C9.4 2 4 7.4 4 14c0 9.3 12 26 12 26s12-16.7 12-26C28 7.4 22.6 2 16 2z"
      fill="url(#g${id})"/>
    <circle cx="16" cy="14" r="4.5" fill="rgba(255,255,255,0.88)"/>
  </svg>`;
  return L.divIcon({
    html: svg,
    className: "",
    iconSize:   [32, 42],
    iconAnchor: [16, 42],
    popupAnchor:[0, -40],
  });
}

// ── Cluster icon — círculo con borde y sombra ─────────────────────────────────
function makeClusterIcon(color) {
  return function(cluster) {
    const count = cluster.getChildCount();
    const size  = count < 10 ? 38 : count < 50 ? 46 : 54;
    return L.divIcon({
      html: `<div style="
        width:${size}px;height:${size}px;
        background:${color};
        border:3px solid rgba(255,255,255,0.95);
        border-radius:50%;
        display:flex;align-items:center;justify-content:center;
        font-weight:800;font-size:${count>=100?11:14}px;color:#fff;
        box-shadow:0 3px 12px rgba(0,0,0,0.35);
      ">${count}</div>`,
      className: "",
      iconSize:   [size, size],
      iconAnchor: [size/2, size/2],
    });
  };
}

// ── FitBounds ─────────────────────────────────────────────────────────────────
function FitBounds({ points }) {
  const map = useMap();
  useEffect(() => {
    if (!points.length) return;
    if (points.length === 1) { map.setView([points[0].lat, points[0].lng], 13); return; }
    const lats = points.map(p => p.lat);
    const lngs = points.map(p => p.lng);
    map.fitBounds(
      [[Math.min(...lats), Math.min(...lngs)], [Math.max(...lats), Math.max(...lngs)]],
      { padding: [60, 60], maxZoom: 14 }
    );
  }, [points, map]);
  return null;
}


// ── FullscreenControl ─────────────────────────────────────────────────────────
function FullscreenControl() {
  const map = useMap();
  useEffect(() => {
    if (!map) return;
    const ctrl = L.control({ position: "topright" });
    ctrl.onAdd = () => {
      const div = L.DomUtil.create("div", "leaflet-bar leaflet-control");
      div.style.cssText = "background:#fff;cursor:pointer;width:30px;height:30px;display:flex;align-items:center;justify-content:center;font-size:15px;border:2px solid rgba(0,0,0,0.2);border-radius:4px;user-select:none;";
      div.title = "Pantalla completa";
      div.innerHTML = "⛶";
      L.DomEvent.on(div, "click", e => {
        L.DomEvent.stopPropagation(e);
        const el = map.getContainer();
        if (!document.fullscreenElement) { el.requestFullscreen?.(); div.innerHTML = "✕"; }
        else { document.exitFullscreen?.(); div.innerHTML = "⛶"; }
      });
      document.addEventListener("fullscreenchange", () => {
        if (!document.fullscreenElement) div.innerHTML = "⛶";
      });
      return div;
    };
    ctrl.addTo(map);
    return () => ctrl.remove();
  }, [map]);
  return null;
}

// ── Leyenda ───────────────────────────────────────────────────────────────────
function LeyendaControl({ leyenda, isDark }) {
  const map = useMap();
  useEffect(() => {
    if (!map || !leyenda?.length) return;
    const ctrl = L.control({ position: "bottomright" });
    ctrl.onAdd = () => {
      const div = L.DomUtil.create("div");
      div.style.cssText = `
        background:${isDark ? "rgba(26,32,44,0.92)" : "rgba(255,255,255,0.92)"};
        backdrop-filter:blur(4px);padding:10px 14px;border-radius:10px;
        box-shadow:0 2px 12px rgba(0,0,0,0.18);font-size:12px;max-width:180px;
        pointer-events:none;border:1px solid ${isDark?"rgba(255,255,255,0.08)":"rgba(0,0,0,0.08)"};`;
      div.innerHTML = leyenda.map(({ label, color }) => `
        <div style="display:flex;align-items:center;gap:7px;margin-bottom:5px;overflow:hidden;">
          <svg width="14" height="19" viewBox="0 0 14 19" xmlns="http://www.w3.org/2000/svg" style="flex-shrink:0;">
            <path d="M7 1C4.2 1 2 3.2 2 6c0 4.1 5 11.5 5 11.5S12 10.1 12 6C12 3.2 9.8 1 7 1z" fill="${color}" filter="drop-shadow(0 1px 1.5px rgba(0,0,0,0.4))"/>
            <circle cx="7" cy="6" r="2.2" fill="rgba(255,255,255,0.9)"/>
          </svg>
          <span style="color:${isDark?"#E2E8F0":"#2D3748"};white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:600;">${label}</span>
        </div>`).join("");
      return div;
    };
    ctrl.addTo(map);
    return () => ctrl.remove();
  }, [map, leyenda, isDark]);
  return null;
}

// ── PopupRegistro ─────────────────────────────────────────────────────────────
function PopupRegistro({ row, camposPopup, resolverFK }) {
  return (
    <Box style={{ fontSize:13, lineHeight:1.7 }}>
      {camposPopup.map(f => {
        const raw = row[f.campo];
        if (raw == null || raw === "") return null;
        const val = f.is_fk ? resolverFK(f.campo, raw)
          : (f.tipo?.includes("timestamp") || f.campo === "created_at")
          ? new Date(raw).toLocaleDateString("es-AR") : String(raw);
        return (
          <Box key={f.campo} style={{ display:"flex", gap:8, marginBottom:3 }}>
            <Text component="span" size="xs" fw={700} c="dimmed" style={{ minWidth:90, flexShrink:0 }}>
              {f.label || f.campo.replace(/_/g," ")}:
            </Text>
            <Text component="span" size="xs">{val}</Text>
          </Box>
        );
      })}
    </Box>
  );
}

// ── MapContent ────────────────────────────────────────────────────────────────
function MapContent({ points, isDark, height, agrupado, colorPorGrupo,
  resolverFK, camposPopup, leyenda, variablePrincipal }) {

  const center = useMemo(() => {
    if (!points.length) return [-27.36, -55.90];
    return [
      points.reduce((s,p) => s+p.lat, 0)/points.length,
      points.reduce((s,p) => s+p.lng, 0)/points.length,
    ];
  }, [points]);

  // En modo agrupado: un MCG por grupo con su color propio
  // En modo individual: un MCG único
  const grupos = useMemo(() => {
    if (!agrupado) return null;
    const g = {};
    points.forEach(p => {
      const key = p.grupoKey;
      if (!g[key]) g[key] = { color: p.color, label: p.label, rows: [] };
      g[key].rows.push(p);
    });
    return g;
  }, [agrupado, points]);

  return (
    <MapContainer center={center} zoom={7}
      style={{ height, width:"100%", borderRadius:12, zIndex:0,
        border:`1px solid ${isDark?"#2D3748":"#E2E8F0"}` }}
      scrollWheelZoom={true}
    >
      <TileLayer
        attribution='&copy; OpenStreetMap'
        url={isDark
          ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
          : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"}
      />
      {points.length > 0 && <FitBounds points={points} />}
      <ScaleControl position="bottomleft" imperial={false} />
      <LeyendaControl leyenda={leyenda} isDark={isDark} />

      {/* ── MODO AGRUPADO: un MCG por grupo con su color → spiderfy nativo ── */}
      {agrupado && grupos && Object.entries(grupos).map(([key, g]) => (
        <MarkerClusterGroup
          key={key}
          chunkedLoading
          animate={true}
          spiderfyOnMaxZoom={true}
          showCoverageOnHover={false}
          zoomToBoundsOnClick={true}
          maxClusterRadius={20}
          iconCreateFunction={makeClusterIcon(g.color)}
        >
          {g.rows.map((p, i) => (
            <Marker key={p.row?.id ?? i} position={[p.lat, p.lng]}
              icon={makePinIcon(g.color)}>
              <Popup minWidth={220} maxWidth={320}>
                <PopupRegistro row={p.row} camposPopup={camposPopup} resolverFK={resolverFK} />
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      ))}

      {/* ── MODO INDIVIDUAL clusters ── */}
      {!agrupado && points.length > 0 && (
        <MarkerClusterGroup
          chunkedLoading animate={true}
          spiderfyOnMaxZoom={true} showCoverageOnHover={false}
          zoomToBoundsOnClick={true} maxClusterRadius={60}
          iconCreateFunction={makeClusterIcon("#22b8cf")}
        >
          {points.map(({ lat, lng, row, color }, i) => (
            <Marker key={row?.id ?? i} position={[lat, lng]}
              icon={makePinIcon(color)}>
              <Popup minWidth={220} maxWidth={320}>
                <PopupRegistro row={row} camposPopup={camposPopup} resolverFK={resolverFK} />
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      )}
    </MapContainer>
  );
}

// ── COMPONENTE PRINCIPAL ──────────────────────────────────────────────────────
export default function MapaReporte({
  data, metadata, columnasSeleccionadas, resolverFK, isDark,
  municipiosCentroideCache = {},
}) {
  const [fullscreenOpen, setFullscreenOpen] = useState(false);

  const toNum = v => (v == null || v === "" || v === "null") ? NaN : parseFloat(v);

  const variablePrincipal = columnasSeleccionadas[0] ?? null;
  const esMunicipio    = variablePrincipal === "municipio_id";
  const esDepartamento = variablePrincipal === "departamento_id";
  const modoAgrupado   = esMunicipio || esDepartamento;

  const departamentoCentroideCache = useMemo(() => {
    const grupos = {};
    Object.values(municipiosCentroideCache).forEach(c => {
      if (!c.departamento_id) return;
      if (!grupos[c.departamento_id]) grupos[c.departamento_id] = [];
      grupos[c.departamento_id].push(c);
    });
    const result = {};
    Object.entries(grupos).forEach(([id, cs]) => {
      result[id] = {
        lat: cs.reduce((s,c) => s+c.lat,0)/cs.length,
        lng: cs.reduce((s,c) => s+c.lng,0)/cs.length,
      };
    });
    return result;
  }, [municipiosCentroideCache]);

  const colorPorValor = useMemo(() => {
    if (!variablePrincipal) return {};
    const unicos = [...new Set(data.map(r => r[variablePrincipal]).filter(v => v!=null))];
    const map = {};
    unicos.forEach((v,i) => { map[v] = PALETA[i%PALETA.length]; });
    return map;
  }, [data, variablePrincipal]);

  const leyenda = useMemo(() => {
    if (!variablePrincipal) return [];
    return Object.entries(colorPorValor).map(([val, color]) => ({
      label: resolverFK(variablePrincipal, val) ?? String(val), color,
    }));
  }, [colorPorValor, variablePrincipal, resolverFK]);

  // En modo agrupado: un punto por registro, todos en el centroide del grupo
  // grupoKey permite separar en MCGs distintos por color
  const puntosAgrupados = useMemo(() => {
    if (!modoAgrupado) return [];
    return data.flatMap(row => {
      const val = row[variablePrincipal];
      if (val == null) return [];
      let lat, lng;
      if (esMunicipio) {
        const c = municipiosCentroideCache[val];
        if (!c) return [];
        lat = c.lat; lng = c.lng;
      } else {
        const c = departamentoCentroideCache[val];
        if (c) { lat = c.lat; lng = c.lng; }
        else {
          const munIds = [...new Set(data.filter(r=>r[variablePrincipal]===val).map(r=>r.municipio_id).filter(Boolean))];
          const coords = munIds.map(id=>municipiosCentroideCache[id]).filter(Boolean);
          if (!coords.length) return [];
          lat = coords.reduce((s,c)=>s+c.lat,0)/coords.length;
          lng = coords.reduce((s,c)=>s+c.lng,0)/coords.length;
        }
      }
      return [{ lat, lng, row, grupoKey: String(val),
        color: colorPorValor[val]??"#22b8cf",
        label: resolverFK(variablePrincipal, val)??String(val) }];
    });
  }, [modoAgrupado, data, variablePrincipal, esMunicipio, municipiosCentroideCache,
      departamentoCentroideCache, colorPorValor, resolverFK]);

  const puntosIndividuales = useMemo(() => {
    if (modoAgrupado) return [];
    const colDef = metadata.find(f => f.campo === variablePrincipal);
    const isNumeric = colDef && !colDef.is_fk && TIPOS_NUM.has(colDef?.tipo?.toLowerCase());
    let getColor;
    if (variablePrincipal && isNumeric) {
      const vals = data.map(r=>parseFloat(r[variablePrincipal])).filter(v=>!isNaN(v));
      const min=Math.min(...vals), range=Math.max(...vals)-min||1;
      getColor = row => {
        const v=parseFloat(row[variablePrincipal]);
        if(isNaN(v)) return "#718096";
        const t=(v-min)/range;
        return `rgb(${Math.round(34+t*221)},${Math.round(184+t*(146-184))},${Math.round(207+t*(43-207))})`;
      };
    } else {
      getColor = row => colorPorValor[row[variablePrincipal]]??"#22b8cf";
    }
    return data.map(row => {
      let lat=toNum(row.latitud_decimal??row.latitud??row.lat??row.latitude);
      let lng=toNum(row.longitud_decimal??row.longitud??row.lng??row.longitude??row.lon);
      if((isNaN(lat)||isNaN(lng))&&row.municipio_id){
        const c=municipiosCentroideCache[row.municipio_id];
        if(c){lat=c.lat;lng=c.lng;}
      }
      if(isNaN(lat)||isNaN(lng)||lat<-90||lat>90||lng<-180||lng>180) return null;
      return { lat, lng, row, color: getColor(row) };
    }).filter(Boolean);
  }, [modoAgrupado, data, metadata, variablePrincipal, colorPorValor, municipiosCentroideCache]);

  const points = modoAgrupado ? puntosAgrupados : puntosIndividuales;

  const EXCLUIR_POPUP = new Set(["id","geom","user_id","activo","formulario_id","created_by","updated_at"]);
  const camposPopup = useMemo(() => metadata.filter(f => !EXCLUIR_POPUP.has(f.campo)), [metadata]);

  const totalPuntos = points.length;
  const totalZonas  = modoAgrupado ? new Set(points.map(p=>p.grupoKey)).size : 0;

  const sharedProps = {
    points, isDark, agrupado: modoAgrupado,
    colorPorGrupo: colorPorValor,
    resolverFK, camposPopup, leyenda, variablePrincipal,
  };

  const cabecera = (onClose) => (
    <Group justify="space-between" px="xl" pt="lg" pb="sm" style={{ flexShrink:0 }}>
      <Group gap="xs">
        <ThemeIcon variant="light" color="cyan" size="md"><IconMap2 size={16}/></ThemeIcon>
        <Text fw={700} size="sm" tt="uppercase" c="dimmed">Distribución geográfica</Text>
        <Badge variant="light" color="cyan" size="sm">
          {modoAgrupado ? `${totalZonas} zona${totalZonas!==1?"s":""} · ${totalPuntos} registros` : `${totalPuntos} punto${totalPuntos!==1?"s":""}`}
        </Badge>
      </Group>
      <Group gap="xs">

        <Tooltip label={onClose?"Cerrar":"Pantalla completa"} withArrow>
          <ActionIcon variant="light" color="cyan" size="sm"
            onClick={onClose??(() => setFullscreenOpen(true))}>
            {onClose ? <IconArrowsMinimize size={14}/> : <IconArrowsMaximize size={14}/>}
          </ActionIcon>
        </Tooltip>
      </Group>
    </Group>
  );

  if (!points.length) {
    return (
      <Box style={{ height:120, display:"flex", alignItems:"center", justifyContent:"center",
        borderRadius:12, margin:"0 1.5rem 1.5rem",
        background: isDark?"rgba(255,255,255,0.03)":"rgba(0,0,0,0.03)",
        border:`1px dashed ${isDark?"#4A5568":"#CBD5E0"}` }}>
        <Text c="dimmed" size="sm">Sin coordenadas para mostrar en el mapa</Text>
      </Box>
    );
  }

  return (
    <>
      <Box>
        {cabecera(null)}
        <Box px="xl" pb="xl">
          <MapContent {...sharedProps} height={600}/>
        </Box>
      </Box>

      {fullscreenOpen && (
        <Box style={{ position:"fixed", inset:0, zIndex:9999,
          background: isDark?"#1A202C":"#fff",
          display:"flex", flexDirection:"column" }}>
          {cabecera(() => setFullscreenOpen(false))}
          <Box style={{ flex:1, minHeight:0, padding:"0 1.5rem 1.5rem" }}>
            <MapContent {...sharedProps} height="100%"/>
          </Box>
        </Box>
      )}
    </>
  );
}