import { useState, useMemo, useEffect, useRef, useCallback } from "react";
import {
  Box,
  Stack,
  Paper,
  Text,
  Grid,
  Center,
  Loader,
  Title as MantineTitle,
  useMantineColorScheme,
  Button,
  Group,
  ThemeIcon,
  Modal,
  Table,
  ColorSwatch,
  Badge,
  TextInput,
  Divider,
  Alert,
  Textarea,
  SegmentedControl,
  ActionIcon,
  Tooltip,
  ScrollArea,
} from "@mantine/core";
import {
  IconFileTypePdf,
  IconPrinter,
  IconSend,
  IconFileDownload,
  IconCheck,
  IconAlertCircle,
  IconChartBar,
  IconChartLine,
  IconChartPie,
  IconCalendar,
  IconVariable,
  IconMath,
  IconLayersIntersect,
  IconPlus,
  IconX,
  IconChevronDown,
  IconChevronUp,
  IconFilter,
  IconRefresh,
} from "@tabler/icons-react";
import { supabase } from "../lib/supabase";
import MapaReporte from "./MapaReporte";
import ReactSelect from "react-select";
import { jsPDF } from "jspdf";
import html2canvas from "html2canvas";
import dayjs from "dayjs";
import "dayjs/locale/es";
import customParseFormat from "dayjs/plugin/customParseFormat";
import Flatpickr from "react-flatpickr";
import "flatpickr/dist/flatpickr.min.css";
import { Spanish } from "flatpickr/dist/l10n/es.js";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Title as ChartTitle,
  Tooltip as ChartTooltip,
  Legend,
  Filler,
} from "chart.js";
import { Bar, Line, Pie } from "react-chartjs-2";
import ChartDataLabels from "chartjs-plugin-datalabels";
import zoomPlugin from "chartjs-plugin-zoom";
import classes from "./VisualizacionEstadisticas.module.css";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  ChartTitle,
  ChartTooltip,
  Legend,
  Filler,
  ChartDataLabels,
  zoomPlugin
);

dayjs.extend(customParseFormat);
dayjs.locale("es");

// ─── Constantes ───────────────────────────────────────────────────────────────
const PALETA = [
  "#22b8cf",
  "#fab005",
  "#12b886",
  "#4c6ef5",
  "#f06595",
  "#ae3ec9",
  "#845ef7",
  "#ff922b",
  "#5c7cfa",
  "#94d82d",
];

const TIPOS_NUMERICOS = new Set([
  "integer",
  "bigint",
  "numeric",
  "real",
  "double precision",
  "smallint",
  "decimal",
  "float",
  "float4",
  "float8",
  "int2",
  "int4",
  "int8",
]);

const OPCIONES_AGRUPACION = [
  { value: "day", label: "Diaria" },
  { value: "month", label: "Mensual" },
  { value: "year", label: "Anual" },
];

const FILTROS_RAPIDOS = [
  { value: "ultimo_mes", label: "Último mes" },
  { value: "este_año", label: "Este año" },
  { value: "ultimo_año", label: "Último año" },
  { value: "historico", label: "Histórico" },
];

const OPERACIONES_NUMERICAS = [
  { value: "count", label: "Contar registros" },
  { value: "sum", label: "Sumar" },
  { value: "avg", label: "Promedio" },
  { value: "max", label: "Máximo" },
  { value: "min", label: "Mínimo" },
];

const OPERACIONES_TEXTO = [
  { value: "count", label: "Contar por categoría" },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────
function getLabelTemporal(fecha, agrupacion) {
  const d = dayjs(fecha);
  if (agrupacion === "day") return d.format("DD/MM/YYYY");
  if (agrupacion === "month") return d.locale("es").format("MMM YYYY").toUpperCase();
  return d.format("YYYY");
}

function parseLabelAFecha(label, agrupacion) {
  if (agrupacion === "day") return dayjs(label, "DD/MM/YYYY");
  if (agrupacion === "month") return dayjs(label, "MMM YYYY", "es");
  return dayjs(label, "YYYY");
}

function aplicarOperacion(filas, col, operacion) {
  if (operacion === "count") return filas.length;
  const nums = filas.map((r) => parseFloat(r[col])).filter((v) => !isNaN(v));
  if (!nums.length) return 0;
  if (operacion === "sum") return nums.reduce((a, b) => a + b, 0);
  if (operacion === "avg")
    return parseFloat((nums.reduce((a, b) => a + b, 0) / nums.length).toFixed(2));
  if (operacion === "max") return Math.max(...nums);
  if (operacion === "min") return Math.min(...nums);
  return 0;
}

// Comparar dos arrays de fechas para evitar refetch innecesario
function fechasIguales(rango1, rango2) {
  if (!rango1 || !rango2) return rango1 === rango2;
  if (rango1.length !== rango2.length) return false;
  if (rango1.length === 0 && rango2.length === 0) return true;
  const d1a = rango1[0] ? dayjs(rango1[0]).valueOf() : null;
  const d1b = rango1[1] ? dayjs(rango1[1]).valueOf() : null;
  const d2a = rango2[0] ? dayjs(rango2[0]).valueOf() : null;
  const d2b = rango2[1] ? dayjs(rango2[1]).valueOf() : null;
  return d1a === d2a && d1b === d2b;
}

// ─── Componente Principal ─────────────────────────────────────────────────────
export default function VisualizacionEstadisticas({ formulario }) {
  const { colorScheme } = useMantineColorScheme();
  const isDark = colorScheme === "dark";
  const reportAreaRef = useRef(null);
  const chartRef = useRef(null);
  const lastFetchRef = useRef({ fechaRango: null, timestamp: 0 });

  // ── Datos ─────────────────────────────────────────────────────────────────
  const [metadata, setMetadata] = useState([]);
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [fkCache, setFkCache] = useState({});
  const [municipiosCentroideCache, setMunicipiosCentroideCache] = useState({});

  // ── Config del reporte ────────────────────────────────────────────────────
  const [filtroRapido, setFiltroRapido] = useState("historico");
  const [fechaRango, setFechaRango] = useState([]);
  const [fechaExpandida, setFechaExpandida] = useState(false);
  const [variablePrincipal, setVariablePrincipal] = useState(null);
  const [operacion, setOperacion] = useState("count");
  const [desglosarPor, setDesglosarPor] = useState(null);
  const [variablesExtra, setVariablesExtra] = useState([]);
  const [agrupacion, setAgrupacion] = useState("year");
  const [tipoGrafico, setTipoGrafico] = useState("bar");

  // ── Export / email ────────────────────────────────────────────────────────
  const [openedExport, setOpenedExport] = useState(false);
  const [emailDestino, setEmailDestino] = useState("");
  const [emailMensaje, setEmailMensaje] = useState("");
  const [enviandoEmail, setEnviandoEmail] = useState(false);
  const [emailEstado, setEmailEstado] = useState(null);

  // ── Metadata ──────────────────────────────────────────────────────────────
  useEffect(() => {
    async function fetchMetadata() {
      if (!formulario?.slug) return;
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/formulario-metadata?slug=${formulario.slug}`,
        { headers: { Authorization: `Bearer ${session.access_token}` } }
      );
      const json = await res.json();
      setMetadata(json.fields || []);
      setVariablePrincipal(null);
      setDesglosarPor(null);
      setVariablesExtra([]);
      setOperacion("count");
    }
    fetchMetadata();
  }, [formulario?.slug]);

  // ── FK cache ──────────────────────────────────────────────────────────────
  useEffect(() => {
    async function fetchFkTables() {
      const TABLAS_EXCLUIDAS = new Set(["users", "formularios", "profiles", "auth"]);
      const fkFields = metadata.filter(
        (f) => f.is_fk && f.foreign_table && !TABLAS_EXCLUIDAS.has(f.foreign_table)
      );
      if (!fkFields.length) return;
      const tablasUnicas = [...new Set(fkFields.map((f) => f.foreign_table))];
      const nuevasEntradas = {};
      await Promise.all(
        tablasUnicas.map(async (tabla) => {
          if (fkCache[tabla]) return;
          try {
            const { data: rows, error } = await supabase
              .from(tabla)
              .select(
                tabla === "municipios"
                  ? "id, nombre, latitud_geografica, longitud_geografica, departamento_id"
                  : "id, nombre"
              )
              .eq("activo", true);
            if (!error && rows) {
              nuevasEntradas[tabla] = Object.fromEntries(rows.map((r) => [r.id, r.nombre]));
              if (tabla === "municipios") {
                const centroides = {};
                rows.forEach((r) => {
                  if (r.latitud_geografica != null && r.longitud_geografica != null) {
                    centroides[r.id] = {
                      lat: parseFloat(r.latitud_geografica),
                      lng: parseFloat(r.longitud_geografica),
                      departamento_id: r.departamento_id ?? null,
                    };
                  }
                });
                setMunicipiosCentroideCache(centroides);
              }
            }
          } catch (e) {
            console.warn(`No se pudo cargar FK: ${tabla}`);
          }
        })
      );
      if (Object.keys(nuevasEntradas).length > 0)
        setFkCache((prev) => ({ ...prev, ...nuevasEntradas }));
    }
    fetchFkTables();
  }, [metadata]);

  const resolverFK = useCallback((col, uuid) => {
    if (!uuid) return null;
    const meta = metadata.find((f) => f.campo === col);
    if (!meta?.foreign_table) return String(uuid);
    const tabla = fkCache[meta.foreign_table];
    if (!tabla) return String(uuid);
    return tabla[uuid] ?? String(uuid);
  }, [metadata, fkCache]);

  // ── Carga de datos ────────────────────────────────────────────────────────
  const fetchData = useCallback(async (force = false) => {
    if (!formulario?.slug) return;

    // Evitar refetch si el rango no cambió y no es forzado
    if (!force && fechasIguales(fechaRango, lastFetchRef.current.fechaRango)) {
      if (Date.now() - lastFetchRef.current.timestamp < 300000) {
        // 5 minutos de cache
        return;
      }
    }

    setLoading(true);
    try {
      let query = supabase.from(formulario.slug).select("*").eq("activo", true);
      if (fechaRango?.length === 2 && fechaRango[0] && fechaRango[1]) {
        query = query
          .gte("created_at", dayjs(fechaRango[0]).startOf("day").toISOString())
          .lte("created_at", dayjs(fechaRango[1]).endOf("day").toISOString());
      }
      const { data: records, error } = await query;
      if (!error) {
        setData(records || []);
        lastFetchRef.current = { fechaRango: [...(fechaRango || [])], timestamp: Date.now() };
      }
    } finally {
      setLoading(false);
    }
  }, [formulario?.slug, fechaRango]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Refrescar datos cuando el usuario vuelve al panel (con debounce)
  useEffect(() => {
    const handleVisibility = () => {
      if (document.visibilityState === "visible") {
        // Solo refrescar si pasaron más de 5 minutos desde el último fetch
        if (Date.now() - lastFetchRef.current.timestamp > 300000) {
          fetchData();
        }
      }
    };
    document.addEventListener("visibilitychange", handleVisibility);
    return () => document.removeEventListener("visibilitychange", handleVisibility);
  }, [fetchData]);

  // ── Opciones de variables ─────────────────────────────────────────────────
  const EXCLUIR = [
    "id",
    "geom",
    "user_id",
    "activo",
    "formulario_id",
    "fecha",
    "created_at",
    "updated_at",
    "created_by",
  ];

  const opcionesVariables = useMemo(() => {
    return metadata
      .filter((f) => !EXCLUIR.includes(f.campo))
      .map((f, i) => ({
        value: f.campo,
        label: f.label || f.campo.replace(/_/g, " ").toUpperCase(),
        color: PALETA[i % PALETA.length],
        tipo: f.tipo,
        is_fk: f.is_fk,
        esNumerica: !f.is_fk && TIPOS_NUMERICOS.has(f.tipo?.toLowerCase()),
      }));
  }, [metadata]);

  const getColorForCol = (col) =>
    opcionesVariables.find((o) => o.value === col)?.color || PALETA[0];

  const esNumerica = useCallback(
    (col) => {
      const meta = metadata.find((f) => f.campo === col);
      if (!meta) return false;
      if (meta.is_fk) return false;
      return TIPOS_NUMERICOS.has(meta.tipo?.toLowerCase());
    },
    [metadata]
  );

  const operacionesDisponibles = useMemo(() => {
    if (!variablePrincipal) return [];
    return esNumerica(variablePrincipal) ? OPERACIONES_NUMERICAS : OPERACIONES_TEXTO;
  }, [variablePrincipal, esNumerica]);

  useEffect(() => {
    if (!variablePrincipal) return;
    const ops = esNumerica(variablePrincipal) ? OPERACIONES_NUMERICAS : OPERACIONES_TEXTO;
    if (!ops.find((o) => o.value === operacion)) {
      setOperacion(ops[0].value);
    }
    setDesglosarPor(null);
    setVariablesExtra([]);
  }, [variablePrincipal]);

  const opcionesDesglose = useMemo(() => {
    const usadas = new Set([variablePrincipal, ...variablesExtra.map((v) => v.campo)]);
    return opcionesVariables.filter((o) => !usadas.has(o.value) && !o.esNumerica);
  }, [opcionesVariables, variablePrincipal, variablesExtra]);

  const opcionesExtra = useMemo(() => {
    const usadas = new Set([variablePrincipal, desglosarPor, ...variablesExtra.map((v) => v.campo)]);
    return opcionesVariables.filter((o) => !usadas.has(o.value) && o.esNumerica);
  }, [opcionesVariables, variablePrincipal, desglosarPor, variablesExtra]);

  const agregarVariableExtra = () => {
    if (!opcionesExtra.length) return;
    setVariablesExtra((prev) => [...prev, { campo: opcionesExtra[0].value, operacion: "sum" }]);
  };

  const actualizarVariableExtra = (idx, campo, op) => {
    setVariablesExtra((prev) =>
      prev.map((v, i) => (i === idx ? { campo, operacion: op } : v))
    );
  };

  const eliminarVariableExtra = (idx) => {
    setVariablesExtra((prev) => prev.filter((_, i) => i !== idx));
  };

  const modoTexto = variablePrincipal ? !esNumerica(variablePrincipal) : false;
  const tieneMultipleSeries = !!(desglosarPor || variablesExtra.length);

  useEffect(() => {
    if (tieneMultipleSeries && tipoGrafico === "pie") setTipoGrafico("bar");
  }, [tieneMultipleSeries]);

  // ── Procesamiento ─────────────────────────────────────────────────────────
  const processedData = useMemo(() => {
    const empty = {
      labels: [],
      datasets: [],
      totalGeneral: 0,
      nombresVariables: [],
      pieColors: null,
    };
    if (!data.length || !variablePrincipal) return empty;

    const validData = data.filter((row) => row.created_at);

    if (modoTexto) {
      if (desglosarPor) {
        const valoresPrincipalRaw = [
          ...new Set(validData.map((r) => r[variablePrincipal]).filter((v) => v != null && v !== "")),
        ];
        const valoresDesgloseRaw = [
          ...new Set(validData.map((r) => r[desglosarPor]).filter((v) => v != null && v !== "")),
        ];

        const totalesPorDesglose = {};
        valoresDesgloseRaw.forEach((vd) => {
          totalesPorDesglose[vd] = validData.filter((r) => r[desglosarPor] === vd).length;
        });

        const labelsXraw = [...valoresDesgloseRaw].sort(
          (a, b) => totalesPorDesglose[b] - totalesPorDesglose[a]
        );
        const labelsX = labelsXraw.map((v) => resolverFK(desglosarPor, v));

        const datasets = valoresPrincipalRaw.map((vp, i) => {
          const label = resolverFK(variablePrincipal, vp);
          const color = PALETA[i % PALETA.length];
          return {
            label,
            data: labelsXraw.map(
              (vd) =>
                validData.filter(
                  (r) => r[variablePrincipal] === vp && r[desglosarPor] === vd
                ).length
            ),
            backgroundColor: color + "BB",
            borderColor: color,
            borderWidth: 2,
            fill: false,
            pointRadius: 4,
            pointHoverRadius: 8,
            pointBackgroundColor: color,
            pointBorderColor: isDark ? "#1A202C" : "#ffffff",
            pointBorderWidth: 2,
            tension: 0.4,
          };
        });

        const total = datasets.reduce(
          (acc, ds) => acc + ds.data.reduce((a, b) => a + b, 0),
          0
        );
        return {
          labels: labelsX,
          datasets,
          totalGeneral: total,
          nombresVariables: valoresPrincipalRaw.map((v) => resolverFK(variablePrincipal, v)),
          pieColors: null,
        };
      }

      const grupos = {};
      validData.forEach((row) => {
        const val = row[variablePrincipal];
        if (val === null || val === undefined || val === "") return;
        const key = resolverFK(variablePrincipal, val);
        grupos[key] = (grupos[key] || 0) + 1;
      });

      const labelsOrdenados = Object.keys(grupos).sort((a, b) => grupos[b] - grupos[a]);
      const total = Object.values(grupos).reduce((a, b) => a + b, 0);
      const bgColors = labelsOrdenados.map((_, i) => PALETA[i % PALETA.length]);

      if (tipoGrafico === "pie") {
        return {
          labels: labelsOrdenados,
          datasets: [
            {
              data: labelsOrdenados.map((k) => grupos[k]),
              backgroundColor: bgColors,
              hoverOffset: 20,
              borderWidth: 3,
              borderColor: isDark ? "#1A202C" : "#ffffff",
            },
          ],
          totalGeneral: total,
          nombresVariables: [
            opcionesVariables.find((o) => o.value === variablePrincipal)?.label ||
              variablePrincipal,
          ],
          pieColors: bgColors,
        };
      }

      return {
        labels: labelsOrdenados,
        datasets: [
          {
            label:
              opcionesVariables.find((o) => o.value === variablePrincipal)?.label ||
              variablePrincipal,
            data: labelsOrdenados.map((k) => grupos[k]),
            backgroundColor: labelsOrdenados.map(
              (_, i) => PALETA[i % PALETA.length] + "BB"
            ),
            borderColor: labelsOrdenados.map((_, i) => PALETA[i % PALETA.length]),
            borderWidth: 2,
            fill: false,
            pointRadius: 4,
            pointHoverRadius: 8,
          },
        ],
        totalGeneral: total,
        nombresVariables: [
          opcionesVariables.find((o) => o.value === variablePrincipal)?.label ||
            variablePrincipal,
        ],
        pieColors: null,
      };
    }

    let labelsOrdenadas = Array.from(
      new Set(validData.map((row) => getLabelTemporal(row.created_at, agrupacion)))
    ).sort(
      (a, b) =>
        parseLabelAFecha(a, agrupacion).unix() - parseLabelAFecha(b, agrupacion).unix()
    );

    const isLine = tipoGrafico === "line";
    if (isLine && labelsOrdenadas.length === 1) {
      const soloLabel = labelsOrdenadas[0];
      const d = parseLabelAFecha(soloLabel, agrupacion);
      const fmt =
        agrupacion === "year"
          ? "YYYY"
          : agrupacion === "month"
          ? null
          : "DD/MM/YYYY";
      const prevLabel =
        agrupacion === "month"
          ? d.subtract(1, "month").locale("es").format("MMM YYYY").toUpperCase()
          : d.subtract(1, agrupacion === "year" ? "year" : "day").format(fmt);
      const nextLabel =
        agrupacion === "month"
          ? d.add(1, "month").locale("es").format("MMM YYYY").toUpperCase()
          : d.add(1, agrupacion === "year" ? "year" : "day").format(fmt);
      labelsOrdenadas = [prevLabel, soloLabel, nextLabel];
    }

    if (desglosarPor) {
      const valoresDesglose = [
        ...new Set(
          validData.map((row) => row[desglosarPor]).filter((v) => v != null && v !== "")
        ),
      ];
      const datasets = valoresDesglose.map((val, i) => {
        const label = resolverFK(desglosarPor, val);
        const color = PALETA[i % PALETA.length];
        const valores = labelsOrdenadas.map((label_) => {
          const filas = validData.filter(
            (row) =>
              getLabelTemporal(row.created_at, agrupacion) === label_ &&
              row[desglosarPor] === val
          );
          return aplicarOperacion(filas, variablePrincipal, operacion);
        });
        return {
          label,
          data: valores,
          backgroundColor: isLine ? color + "66" : color + "BB",
          borderColor: color,
          borderWidth: isLine ? 2.5 : 2,
          fill: isLine ? (i === 0 ? "origin" : "-1") : false,
          tension: 0.4,
          pointRadius: isLine ? 5 : 4,
          pointHoverRadius: 8,
          pointBackgroundColor: color,
          pointBorderColor: isDark ? "#1A202C" : "#ffffff",
          pointBorderWidth: 2,
        };
      });
      const total = datasets.reduce(
        (acc, ds) => acc + ds.data.reduce((a, b) => a + b, 0),
        0
      );
      return {
        labels: labelsOrdenadas,
        datasets,
        totalGeneral: total,
        nombresVariables: valoresDesglose.map((v) => resolverFK(desglosarPor, v)),
        pieColors: null,
      };
    }

    const todasVariables = [
      {
        campo: variablePrincipal,
        operacion,
        color: getColorForCol(variablePrincipal),
        label:
          opcionesVariables.find((o) => o.value === variablePrincipal)?.label ||
          variablePrincipal,
      },
      ...variablesExtra.map((v) => ({
        campo: v.campo,
        operacion: v.operacion,
        color: getColorForCol(v.campo),
        label:
          opcionesVariables.find((o) => o.value === v.campo)?.label || v.campo,
      })),
    ];

    if (tipoGrafico === "pie") {
      const counts = todasVariables.map(({ campo, operacion: op }) =>
        aplicarOperacion(validData, campo, op)
      );
      const bgColors = todasVariables.map((v) => v.color);
      const total = counts.reduce((a, b) => a + b, 0);
      return {
        labels: todasVariables.map((v) => v.label),
        datasets: [
          {
            data: counts,
            backgroundColor: bgColors,
            hoverOffset: 20,
            borderWidth: 3,
            borderColor: isDark ? "#1A202C" : "#ffffff",
          },
        ],
        totalGeneral: total,
        nombresVariables: todasVariables.map((v) => v.label),
        pieColors: bgColors,
      };
    }

    const datasets = todasVariables.map(
      ({ campo, operacion: op, color, label }, dsIndex) => {
        const valores = labelsOrdenadas.map((lbl) => {
          const filas = validData.filter(
            (row) => getLabelTemporal(row.created_at, agrupacion) === lbl
          );
          return aplicarOperacion(filas, campo, op);
        });
        return {
          label,
          data: valores,
          backgroundColor: isLine ? color + "66" : color + "BB",
          borderColor: color,
          borderWidth: isLine ? 2.5 : 2,
          fill: isLine ? (dsIndex === 0 ? "origin" : "-1") : false,
          tension: 0.4,
          pointRadius: isLine ? 5 : 4,
          pointHoverRadius: 8,
          pointBackgroundColor: color,
          pointBorderColor: isDark ? "#1A202C" : "#ffffff",
          pointBorderWidth: 2,
        };
      }
    );
    const total = datasets.reduce(
      (acc, ds) => acc + ds.data.reduce((a, b) => a + b, 0),
      0
    );
    return {
      labels: labelsOrdenadas,
      datasets,
      totalGeneral: total,
      nombresVariables: todasVariables.map((v) => v.label),
      pieColors: null,
    };
  }, [
    data,
    variablePrincipal,
    operacion,
    desglosarPor,
    variablesExtra,
    agrupacion,
    tipoGrafico,
    opcionesVariables,
    isDark,
    modoTexto,
    resolverFK,
    fkCache,
  ]);

  // ── Opciones Chart.js ─────────────────────────────────────────────────────
  const axisColor = isDark ? "#A0AEC0" : "#4A5568";
  const gridColor = isDark ? "rgba(45,55,72,0.5)" : "rgba(226,232,240,0.8)";

  const chartOptions = useMemo(() => {
    const isPie = tipoGrafico === "pie";
    const isLine = tipoGrafico === "line";
    const isBar = tipoGrafico === "bar";
    const lineAnimation = {
      x: { duration: 0 },
      y: {
        duration: 800,
        from: (ctx) => {
          if (ctx.type === "data" && ctx.mode === "default" && !ctx.dropped) {
            ctx.dropped = true;
            return 0;
          }
        },
        easing: "easeOutBounce",
      },
    };
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: isLine ? lineAnimation : { duration: 500 },
      layout: {
        padding: { top: isBar ? 24 : 16, right: 8, left: 8, bottom: 4 },
      },
      scales: !isPie
        ? {
            x: {
              ticks: { color: axisColor, maxRotation: 45, font: { size: 12 } },
              grid: { display: false },
              stacked: isLine,
            },
            y: {
              ticks: { color: axisColor, font: { size: 12 } },
              beginAtZero: true,
              grid: { color: gridColor },
              stacked: isLine,
            },
          }
        : {},
      plugins: {
        legend: {
          position: isPie ? "right" : "bottom",
          align: "center",
          labels: {
            color: axisColor,
            padding: isPie ? 16 : 20,
            usePointStyle: true,
            pointStyleWidth: 10,
            font: { size: 13, weight: "600" },
            boxWidth: isPie ? 14 : 10,
          },
        },
        tooltip: {
          backgroundColor: isDark ? "#2D3748" : "#ffffff",
          titleColor: isDark ? "#E2E8F0" : "#1A202C",
          bodyColor: isDark ? "#CBD5E0" : "#4A5568",
          borderColor: isDark ? "#4A5568" : "#E2E8F0",
          borderWidth: 1,
          padding: 12,
          cornerRadius: 8,
          titleFont: { weight: "bold" },
          mode: isLine ? "index" : "nearest",
          intersect: !isLine,
        },
        zoom: !isPie
          ? {
              pan: { enabled: true, mode: "x" },
              zoom: {
                wheel: { enabled: false },
                pinch: { enabled: false },
                mode: "x",
              },
            }
          : false,
        datalabels: {
          display: (ctx) => {
            if (isLine) return false;
            return ctx.dataset.data[ctx.dataIndex] > 0;
          },
          color: "#ffffff",
          backgroundColor: (ctx) => {
            if (isPie) return ctx.dataset.backgroundColor[ctx.dataIndex];
            if (isBar) return ctx.dataset.borderColor;
            return "transparent";
          },
          borderRadius: isPie ? 20 : isBar ? 4 : 0,
          padding: isPie
            ? { top: 5, bottom: 5, left: 12, right: 12 }
            : isBar
            ? { top: 2, bottom: 2, left: 6, right: 6 }
            : 0,
          font: { weight: "bold", size: isPie ? 13 : 11 },
          textShadowColor: "rgba(0,0,0,0.35)",
          textShadowBlur: 4,
          anchor: isBar ? "end" : "center",
          align: isBar ? "end" : "center",
          formatter: (v) =>
            isPie
              ? `${((v * 100) / (processedData.totalGeneral || 1)).toFixed(1)}%`
              : v.toLocaleString("es-AR"),
        },
      },
    };
  }, [tipoGrafico, axisColor, gridColor, isDark, processedData.totalGeneral]);

  // ── Filtros rápidos ───────────────────────────────────────────────────────
  const handleFiltroRapido = (tipo) => {
    setFiltroRapido(tipo);
    const ahora = dayjs();
    if (tipo === "ultimo_mes")
      setFechaRango([ahora.subtract(1, "month").toDate(), ahora.toDate()]);
    else if (tipo === "este_año")
      setFechaRango([ahora.startOf("year").toDate(), ahora.toDate()]);
    else if (tipo === "ultimo_año")
      setFechaRango([ahora.subtract(1, "year").toDate(), ahora.toDate()]);
    else setFechaRango([]);
  };

  // ── Estilos ReactSelect ───────────────────────────────────────────────────
  const selectStyles = useMemo(
    () => ({
      container: (b) => ({ ...b, zIndex: 9999 }),
      menuPortal: (b) => ({ ...b, zIndex: 11000 }),
      control: (b, { isFocused }) => ({
        ...b,
        minHeight: "36px",
        backgroundColor: isDark
          ? "var(--mantine-color-dark-6)"
          : "#fff",
        borderColor: isFocused
          ? "var(--mantine-color-cyan-6)"
          : isDark
          ? "var(--mantine-color-dark-4)"
          : "var(--mantine-color-gray-4)",
        boxShadow: isFocused
          ? "0 0 0 1px var(--mantine-color-cyan-6)"
          : "none",
        "&:hover": { borderColor: "var(--mantine-color-cyan-6)" },
      }),
      singleValue: (b) => ({
        ...b,
        color: isDark ? "#E2E8F0" : "#1A202C",
        fontSize: "13px",
      }),
      input: (b) => ({
        ...b,
        color: isDark ? "#E2E8F0" : "#1A202C",
        fontSize: "13px",
      }),
      placeholder: (b) => ({
        ...b,
        color: isDark ? "#718096" : "#A0AEC0",
        fontSize: "13px",
      }),
      menu: (b) => ({
        ...b,
        backgroundColor: isDark
          ? "var(--mantine-color-dark-6)"
          : "#fff",
        border: `1px solid ${
          isDark
            ? "var(--mantine-color-dark-4)"
            : "var(--mantine-color-gray-3)"
        }`,
        boxShadow: "0 4px 20px rgba(0,0,0,0.15)",
      }),
      option: (b, { isFocused, isSelected }) => ({
        ...b,
        fontSize: "13px",
        backgroundColor: isSelected
          ? "var(--mantine-color-cyan-6)"
          : isFocused
          ? isDark
            ? "var(--mantine-color-dark-4)"
            : "var(--mantine-color-cyan-0)"
          : "transparent",
        color: isSelected
          ? "#fff"
          : isDark
          ? "#E2E8F0"
          : "#1A202C",
        cursor: "pointer",
      }),
    }),
    [isDark]
  );

  // ── Export helpers ────────────────────────────────────────────────────────
  const handlePrint = async () => {
    const canvas = await html2canvas(reportAreaRef.current, {
      scale: 2,
      useCORS: true,
      backgroundColor: isDark ? "#1A202C" : "#ffffff",
    });
    const imgData = canvas.toDataURL("image/png");
    const win = window.open("", "_blank");
    win.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Reporte</title>
<style>*{margin:0;padding:0;box-sizing:border-box;}body{background:#fff;}img{width:100%;display:block;}
@media print{img{width:100%;}}</style></head>
<body><img src="${imgData}"/><script>window.onload=function(){window.print();window.close();}<\/script></body></html>`);
    win.document.close();
  };

  const handleExportPDF = () => {
    html2canvas(reportAreaRef.current, {
      scale: 2,
      useCORS: true,
      backgroundColor: isDark ? "#1A202C" : "#ffffff",
    }).then((canvas) => {
      const pdf = new jsPDF("p", "mm", "a4"); // Portrait para mejor distribución
      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      const margin = 10;
      const maxWidth = pageWidth - margin * 2;
      const maxHeight = pageHeight - margin * 2;

      // Calcular proporciones para mantener aspecto
      const imgWidth = canvas.width;
      const imgHeight = canvas.height;
      const ratio = Math.min(maxWidth / imgWidth, maxHeight / imgHeight);
      const scaledWidth = imgWidth * ratio;
      const scaledHeight = imgHeight * ratio;

      // Si cabe en una página
      if (scaledHeight <= maxHeight) {
        pdf.addImage(
          canvas.toDataURL("image/png"),
          "PNG",
          margin,
          margin,
          scaledWidth,
          scaledHeight
        );
      } else {
        // Dividir en múltiples páginas
        let heightRemaining = scaledHeight;
        let positionY = margin;
        let pageNum = 0;

        while (heightRemaining > 0) {
          if (pageNum > 0) {
            pdf.addPage();
            positionY = margin;
          }

          const sliceHeight = Math.min(heightRemaining, maxHeight);
          const sliceY = (scaledHeight - heightRemaining) * (imgHeight / scaledHeight);

          // Crear canvas temporal para el slice
          const sliceCanvas = document.createElement("canvas");
          sliceCanvas.width = imgWidth;
          sliceCanvas.height = Math.ceil((sliceHeight / scaledHeight) * imgHeight);
          const ctx = sliceCanvas.getContext("2d");
          ctx.drawImage(
            canvas,
            0,
            sliceY,
            imgWidth,
            sliceCanvas.height,
            0,
            0,
            imgWidth,
            sliceCanvas.height
          );

          const scaledSliceHeight = (sliceCanvas.height / imgHeight) * scaledWidth;
          pdf.addImage(
            sliceCanvas.toDataURL("image/png"),
            "PNG",
            margin,
            positionY,
            scaledWidth,
            Math.min(scaledSliceHeight, maxHeight)
          );

          heightRemaining -= sliceHeight;
          pageNum++;
        }
      }

      pdf.save(`Reporte_${dayjs().format("YYYY-MM-DD")}.pdf`);
    });
  };

  const handleSendEmail = async () => {
    if (!emailDestino) return;
    setEnviandoEmail(true);
    setEmailEstado(null);
    try {
      const canvas = await html2canvas(reportAreaRef.current, {
        scale: 2,
        useCORS: true,
        backgroundColor: "#ffffff",
      });
      const flatCanvas = document.createElement("canvas");
      flatCanvas.width = canvas.width;
      flatCanvas.height = canvas.height;
      const ctx = flatCanvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, flatCanvas.width, flatCanvas.height);
      ctx.drawImage(canvas, 0, 0);
      const dataUrl = flatCanvas.toDataURL("image/jpeg", 0.85);

      const pdf = new jsPDF("p", "mm", "a4");
      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      const margin = 10;
      const maxWidth = pageWidth - margin * 2;
      const maxHeight = pageHeight - margin * 2;

      const imgWidth = canvas.width;
      const imgHeight = canvas.height;
      const ratio = Math.min(maxWidth / imgWidth, maxHeight / imgHeight);
      const scaledWidth = imgWidth * ratio;
      const scaledHeight = imgHeight * ratio;

      if (scaledHeight <= maxHeight) {
        pdf.addImage(dataUrl, "JPEG", margin, margin, scaledWidth, scaledHeight);
      } else {
        let heightRemaining = scaledHeight;
        let positionY = margin;
        let pageNum = 0;

        while (heightRemaining > 0) {
          if (pageNum > 0) {
            pdf.addPage();
            positionY = margin;
          }

          const sliceHeight = Math.min(heightRemaining, maxHeight);
          const sliceY = (scaledHeight - heightRemaining) * (imgHeight / scaledHeight);

          const sliceCanvas = document.createElement("canvas");
          sliceCanvas.width = imgWidth;
          sliceCanvas.height = Math.ceil((sliceHeight / scaledHeight) * imgHeight);
          const sliceCtx = sliceCanvas.getContext("2d");
          sliceCtx.drawImage(
            canvas,
            0,
            sliceY,
            imgWidth,
            sliceCanvas.height,
            0,
            0,
            imgWidth,
            sliceCanvas.height
          );

          const scaledSliceHeight = (sliceCanvas.height / imgHeight) * scaledWidth;
          pdf.addImage(
            sliceCanvas.toDataURL("image/jpeg", 0.85),
            "JPEG",
            margin,
            positionY,
            scaledWidth,
            Math.min(scaledSliceHeight, maxHeight)
          );

          heightRemaining -= sliceHeight;
          pageNum++;
        }
      }

      const filename = `Reporte_${tituloReporte.replace(/\s+/g, "_")}_${dayjs().format(
        "YYYY-MM-DD_HH-mm-ss"
      )}.pdf`;
      const pdfBlob = pdf.output("blob");
      const { data: { session } } = await supabase.auth.getSession();
      const storageKey = `${session.user.id}/${filename}`;
      const { error: uploadError } = await supabase.storage
        .from("reportes")
        .upload(storageKey, pdfBlob, { contentType: "application/pdf", upsert: false });
      if (uploadError) throw new Error(`Error al subir PDF: ${uploadError.message}`);

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/queue-publish`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({
            subject: "jobs.reports.send",
            payload: {
              to: emailDestino,
              replyTo: session.user.email,
              subject: `Reporte: ${tituloReporte} — ${dayjs().format("DD/MM/YYYY")}`,
              mensajePersonalizado: emailMensaje.trim() || null,
              storageKey,
              filename,
              titulo: tituloReporte,
              periodo:
                filtroRapido === "personalizado" && fechaRango.length === 2
                  ? `${dayjs(fechaRango[0]).format("DD/MM/YYYY")} — ${dayjs(
                      fechaRango[1]
                    ).format("DD/MM/YYYY")}`
                  : FILTROS_RAPIDOS.find((f) => f.value === filtroRapido)?.label,
            },
          }),
        }
      );
      const json = await res.json();
      if (!res.ok) throw new Error(json.error || "Error al encolar");
      setEmailEstado("ok");
      setEmailDestino("");
      setEmailMensaje("");
    } catch (err) {
      console.error(err);
      setEmailEstado("error");
    } finally {
      setEnviandoEmail(false);
    }
  };

  const tieneGrafico =
    processedData.datasets.length > 0 && processedData.labels.length > 0;

  // ── TÍTULO DEL REPORTE CON NOMBRE DEL FORMULARIO ─────────────────────────
  const tituloReporte = useMemo(() => {
    const partes = [];
    if (formulario?.nombre) {
      partes.push(formulario.nombre);
    }
    if (processedData.nombresVariables.length) {
      partes.push(processedData.nombresVariables.join(" + "));
    }
    return partes.length ? partes.join(" — ") : "Sin selección";
  }, [formulario?.nombre, processedData.nombresVariables]);

  const periodoLabel =
    filtroRapido === "personalizado" && fechaRango.length === 2
      ? `${dayjs(fechaRango[0]).format("DD/MM/YYYY")} — ${dayjs(
          fechaRango[1]
        ).format("DD/MM/YYYY")}`
      : FILTROS_RAPIDOS.find((f) => f.value === filtroRapido)?.label ||
        "Todos los registros";

  // ── Sección del panel izquierdo ───────────────────────────────────────────
  const SectionTitle = ({ icon: Icon, label, color = "cyan" }) => (
    <Group gap={6} mb={8}>
      <ThemeIcon variant="light" color={color} size="sm" radius="sm">
        <Icon size={12} />
      </ThemeIcon>
      <Text size="xs" fw={700} tt="uppercase" c="dimmed" lts="0.5px">
        {label}
      </Text>
    </Group>
  );

  // ─────────────────────────────────────────────────────────────────────────────
  return (
    <Stack gap="lg" className={classes.container}>
      <Grid gutter="lg" align="flex-start">
        {/* ── PANEL IZQUIERDO: Constructor ─────────────────────────────────── */}
        <Grid.Col span={{ base: 12, md: 3 }}>
          
            <Stack gap="xs">
              {/* 1. PERÍODO */}
              <Paper className={classes.panelSection}>
                <SectionTitle icon={IconCalendar} label="Período" />
                <Stack gap={4}>
                  {FILTROS_RAPIDOS.map((f) => (
                    <Button
                      key={f.value}
                      size="xs"
                      variant={filtroRapido === f.value ? "filled" : "subtle"}
                      color="cyan"
                      justify="flex-start"
                      fullWidth
                      onClick={() => handleFiltroRapido(f.value)}
                    >
                      {f.label}
                    </Button>
                  ))}
                  <Button
                    size="xs"
                    variant={
                      fechaExpandida || filtroRapido === "personalizado"
                        ? "light"
                        : "subtle"
                    }
                    color="cyan"
                    justify="flex-start"
                    fullWidth
                    rightSection={
                      fechaExpandida ? (
                        <IconChevronUp size={12} />
                      ) : (
                        <IconChevronDown size={12} />
                      )
                    }
                    onClick={() => setFechaExpandida((v) => !v)}
                  >
                    Personalizado
                  </Button>
                  {fechaExpandida && (
                    <Flatpickr
                      className={classes.flatpickrInput}
                      options={{
                        mode: "range",
                        locale: Spanish,
                        dateFormat: "d/m/Y",
                        allowInput: false,
                        closeOnSelect: false,
                        onReady: (_, __, fp) => {
                          if (isDark)
                            fp.calendarContainer?.classList.add("flatpickr-dark");
                        },
                        onOpen: (_, __, fp) => {
                          isDark
                            ? fp.calendarContainer?.classList.add("flatpickr-dark")
                            : fp.calendarContainer?.classList.remove(
                                "flatpickr-dark"
                              );
                        },
                        onClose: (dates) => {
                          if (dates.length === 2) {
                            setFechaRango(dates);
                            setFiltroRapido("personalizado");
                          } else if (dates.length === 0) {
                            setFechaRango([]);
                            setFiltroRapido("historico");
                          }
                        },
                      }}
                      value={fechaRango}
                      placeholder="Desde — Hasta"
                    />
                  )}
                </Stack>
              </Paper>

              {/* 2. VARIABLE PRINCIPAL */}
              <Paper className={classes.panelSection}>
                <SectionTitle icon={IconVariable} label="Variable a analizar" />
                <ReactSelect
                  placeholder="Elegí una variable..."
                  options={opcionesVariables}
                  styles={selectStyles}
                  menuPortalTarget={document.body}
                  value={
                    opcionesVariables.find((o) => o.value === variablePrincipal) ||
                    null
                  }
                  onChange={(sel) => setVariablePrincipal(sel ? sel.value : null)}
                  isClearable
                />
                {variablePrincipal && (
                  <Badge size="xs" variant="dot" color="cyan" mt={6}>
                    {esNumerica(variablePrincipal) ? "Numérica" : "Categórica"}
                  </Badge>
                )}
              </Paper>

              {/* 3. OPERACIÓN */}
              {variablePrincipal && (
                <Paper className={classes.panelSection}>
                  <SectionTitle icon={IconMath} label="Operación" />
                  <Stack gap={4}>
                    {operacionesDisponibles.map((op) => (
                      <Button
                        key={op.value}
                        size="xs"
                        variant={operacion === op.value ? "filled" : "subtle"}
                        color="indigo"
                        justify="flex-start"
                        fullWidth
                        onClick={() => setOperacion(op.value)}
                      >
                        {op.label}
                      </Button>
                    ))}
                  </Stack>
                </Paper>
              )}

              {/* 4. DESGLOSAR POR */}
              {variablePrincipal && (
                <Paper className={classes.panelSection}>
                  <SectionTitle
                    icon={IconLayersIntersect}
                    label="Desglosar por"
                    color="violet"
                  />
                  <ReactSelect
                    placeholder="Sin desglose..."
                    options={opcionesDesglose}
                    styles={selectStyles}
                    menuPortalTarget={document.body}
                    value={
                      opcionesDesglose.find((o) => o.value === desglosarPor) || null
                    }
                    onChange={(sel) => setDesglosarPor(sel ? sel.value : null)}
                    isClearable
                  />
                  <Text size="xs" c="dimmed" mt={4}>
                    {modoTexto
                      ? "Ej: felinos agrupados por municipio"
                      : "Ej: alevines por mes, separados por especie"}
                  </Text>
                </Paper>
              )}

              {/* 5. COMPARAR VARIABLES EXTRA */}
              {variablePrincipal && (
                <Paper className={classes.panelSection}>
                  <SectionTitle icon={IconFilter} label="Comparar con" color="teal" />
                  <Stack gap={6}>
                    {variablesExtra.map((ve, idx) => (
                      <Box key={idx} className={classes.extraVarRow}>
                        <Group gap={4} wrap="nowrap" mb={4}>
                          <ColorSwatch
                            color={getColorForCol(ve.campo)}
                            size={10}
                          />
                          <Text
                            size="xs"
                            fw={600}
                            style={{ flex: 1 }}
                            truncate
                          >
                            {opcionesVariables.find((o) => o.value === ve.campo)
                              ?.label || ve.campo}
                          </Text>
                          <ActionIcon
                            size="xs"
                            color="red"
                            variant="subtle"
                            onClick={() => eliminarVariableExtra(idx)}
                          >
                            <IconX size={10} />
                          </ActionIcon>
                        </Group>
                        <Group gap={4}>
                          <ReactSelect
                            options={[
                              ...opcionesExtra,
                              opcionesVariables.find((o) => o.value === ve.campo),
                            ].filter(Boolean)}
                            styles={{
                              ...selectStyles,
                              container: (b) => ({
                                ...b,
                                flex: 1,
                                zIndex: 9999 - idx,
                              }),
                            }}
                            menuPortalTarget={document.body}
                            value={
                              opcionesVariables.find((o) => o.value === ve.campo) ||
                              null
                            }
                            onChange={(sel) =>
                              sel &&
                              actualizarVariableExtra(idx, sel.value, ve.operacion)
                            }
                            isSearchable={false}
                          />
                          <ReactSelect
                            options={OPERACIONES_NUMERICAS}
                            styles={{
                              ...selectStyles,
                              container: (b) => ({
                                ...b,
                                width: 90,
                                zIndex: 9999 - idx,
                              }),
                            }}
                            menuPortalTarget={document.body}
                            value={
                              OPERACIONES_NUMERICAS.find(
                                (o) => o.value === ve.operacion
                              ) || null
                            }
                            onChange={(sel) =>
                              sel &&
                              actualizarVariableExtra(idx, ve.campo, sel.value)
                            }
                            isSearchable={false}
                          />
                        </Group>
                      </Box>
                    ))}
                    {opcionesExtra.length > 0 && (
                      <Button
                        size="xs"
                        variant="dashed"
                        color="teal"
                        leftSection={<IconPlus size={12} />}
                        onClick={agregarVariableExtra}
                        fullWidth
                      >
                        Agregar variable
                      </Button>
                    )}
                    {!opcionesExtra.length && !variablesExtra.length && (
                      <Text size="xs" c="dimmed">
                        Solo disponible para variables numéricas
                      </Text>
                    )}
                  </Stack>
                </Paper>
              )}

              {/* 6. AGRUPACIÓN TEMPORAL */}
              {variablePrincipal && !modoTexto && (
                <Paper className={classes.panelSection}>
                  <SectionTitle icon={IconCalendar} label="Agrupar por" />
                  <SegmentedControl
                    fullWidth
                    size="xs"
                    data={OPCIONES_AGRUPACION}
                    value={agrupacion}
                    onChange={setAgrupacion}
                    color="cyan"
                  />
                </Paper>
              )}

              {/* 7. TIPO DE GRÁFICO */}
              {variablePrincipal && (
                <Paper className={classes.panelSection}>
                  <SectionTitle icon={IconChartBar} label="Tipo de gráfico" />
                  <Group gap={6}>
                    {[
                      { value: "bar", icon: IconChartBar, label: "Barras" },
                      { value: "line", icon: IconChartLine, label: "Línea" },
                      { value: "pie", icon: IconChartPie, label: "Torta" },
                    ].map(({ value, icon: Icon, label }) => {
                      const disabled = value === "pie" && tieneMultipleSeries;
                      return (
                        <Tooltip
                          key={value}
                          label={
                            disabled
                              ? "No disponible con múltiples series"
                              : label
                          }
                          withArrow
                        >
                          <Box
                            className={`${classes.chartTypeBtn} ${
                              tipoGrafico === value
                                ? classes.chartTypeBtnActive
                                : ""
                            } ${disabled ? classes.chartTypeBtnDisabled : ""}`}
                            onClick={() => !disabled && setTipoGrafico(value)}
                          >
                            <Icon size={18} />
                            <Text size="xs" fw={600}>
                              {label}
                            </Text>
                          </Box>
                        </Tooltip>
                      );
                    })}
                  </Group>
                </Paper>
              )}
            </Stack>
          
        </Grid.Col>

        {/* ── PANEL DERECHO: Preview ───────────────────────────────────────── */}
        <Grid.Col span={{ base: 12, md: 9 }}>
          <Paper ref={reportAreaRef} className={classes.chartArea}>
            <Stack gap={0}>
              {/* Cabecera */}
              <Group justify="space-between" p="xl" className={classes.chartHeader}>
                <Box>
                  <Text size="xs" c="dimmed" fw={600} tt="uppercase" mb={2}>
                    {periodoLabel}
                  </Text>
                  <MantineTitle order={4} fw={800} c={isDark ? "white" : "dark"}>
                    {tituloReporte}
                  </MantineTitle>
                </Box>
                <Group gap="xs">
                  <Tooltip label="Actualizar datos" withArrow>
                    <ActionIcon
                      variant="light"
                      color="cyan"
                      size="lg"
                      onClick={() => fetchData(true)}
                      loading={loading}
                    >
                      <IconRefresh size={16} />
                    </ActionIcon>
                  </Tooltip>
                  <Button
                    leftSection={<IconFileTypePdf size={16} />}
                    color="red"
                    variant="light"
                    onClick={() => setOpenedExport(true)}
                    disabled={!tieneGrafico}
                  >
                    Exportar
                  </Button>
                </Group>
              </Group>

              {/* Contenido */}
              {loading ? (
                <Center h={400}>
                  <Stack align="center" gap="sm">
                    <Loader color="cyan" size="lg" />
                    <Text c="dimmed" size="sm">
                      Cargando datos...
                    </Text>
                  </Stack>
                </Center>
              ) : !variablePrincipal ? (
                <Center h={400}>
                  <Stack align="center" gap="xs">
                    <Text size="xl">📊</Text>
                    <Text fw={600} c="dimmed">
                      Elegí una variable en el panel izquierdo
                    </Text>
                    <Text size="sm" c="dimmed">
                      El gráfico se actualiza en tiempo real
                    </Text>
                  </Stack>
                </Center>
              ) : !tieneGrafico ? (
                <Center h={400}>
                  <Stack align="center" gap="xs">
                    <Text size="xl">🔍</Text>
                    <Text fw={600} c="dimmed">
                      No hay datos para el período seleccionado
                    </Text>
                    <Text size="sm" c="dimmed">
                      Probá cambiando el rango de fechas
                    </Text>
                  </Stack>
                </Center>
              ) : (
                <>
                  <Box className={classes.chartCanvasContainer}>
                    {tipoGrafico === "bar" && (
                      <Bar
                        ref={chartRef}
                        data={{
                          labels: processedData.labels,
                          datasets: processedData.datasets,
                        }}
                        options={chartOptions}
                      />
                    )}
                    {tipoGrafico === "line" && (
                      <Line
                        ref={chartRef}
                        data={{
                          labels: processedData.labels,
                          datasets: processedData.datasets,
                        }}
                        options={chartOptions}
                      />
                    )}
                    {tipoGrafico === "pie" && (
                      <Pie
                        ref={chartRef}
                        data={{
                          labels: processedData.labels,
                          datasets: processedData.datasets,
                        }}
                        options={chartOptions}
                      />
                    )}
                  </Box>
                  <Table striped highlightOnHover className={classes.tabla}>
                    <Table.Thead>
                      <Table.Tr>
                        <Table.Th pl="xl">
                          <Text
                            size="xs"
                            fw={700}
                            tt="uppercase"
                            c={isDark ? "gray.4" : "dark"}
                          >
                            Variable
                          </Text>
                        </Table.Th>
                        <Table.Th ta="center">
                          <Text
                            size="xs"
                            fw={700}
                            tt="uppercase"
                            c={isDark ? "gray.4" : "dark"}
                          >
                            Valor
                          </Text>
                        </Table.Th>
                        <Table.Th ta="center" pr="xl">
                          <Text
                            size="xs"
                            fw={700}
                            tt="uppercase"
                            c={isDark ? "gray.4" : "dark"}
                          >
                            % del total
                          </Text>
                        </Table.Th>
                      </Table.Tr>
                    </Table.Thead>
                    <Table.Tbody>
                      {(tipoGrafico === "pie" ||
                      processedData.datasets.length > 1 ||
                      modoTexto
                        ? processedData.labels.map((label, i) => {
                            const val = processedData.datasets[0]?.data[i] ?? 0;
                            const color =
                              processedData.pieColors?.[i] ??
                              processedData.datasets[0]?.backgroundColor?.[i] ??
                              PALETA[i % PALETA.length];
                            const pct = processedData.totalGeneral
                              ? (
                                  (val * 100) / processedData.totalGeneral
                                ).toFixed(1)
                              : "0.0";
                            const colorStr =
                              typeof color === "string"
                                ? color.replace(/BB$|66$/, "")
                                : PALETA[i % PALETA.length];
                            return (
                              <Table.Tr key={i}>
                                <Table.Td pl="xl">
                                  <Group gap="xs">
                                    <ColorSwatch color={colorStr} size={12} />
                                    <Text
                                      size="sm"
                                      fw={600}
                                      c={isDark ? "gray.2" : "dark"}
                                    >
                                      {label}
                                    </Text>
                                  </Group>
                                </Table.Td>
                                <Table.Td
                                  ta="center"
                                  fw={700}
                                  c={isDark ? "gray.2" : "dark"}
                                >
                                  {typeof val === "number"
                                    ? val.toLocaleString("es-AR")
                                    : val}
                                </Table.Td>
                                <Table.Td ta="center" pr="xl">
                                  <Badge variant="light" color="cyan">
                                    {pct}%
                                  </Badge>
                                </Table.Td>
                              </Table.Tr>
                            );
                          })
                        : processedData.datasets.map((ds, i) => {
                            const total = ds.data.reduce((a, b) => a + b, 0);
                            const pct = processedData.totalGeneral
                              ? (
                                  (total * 100) / processedData.totalGeneral
                                ).toFixed(1)
                              : "0.0";
                            const color =
                              typeof ds.borderColor === "string"
                                ? ds.borderColor
                                : PALETA[i % PALETA.length];
                            return (
                              <Table.Tr key={i}>
                                <Table.Td pl="xl">
                                  <Group gap="xs">
                                    <ColorSwatch color={color} size={12} />
                                    <Text
                                      size="sm"
                                      fw={600}
                                      c={isDark ? "gray.2" : "dark"}
                                    >
                                      {ds.label}
                                    </Text>
                                  </Group>
                                </Table.Td>
                                <Table.Td
                                  ta="center"
                                  fw={700}
                                  c={isDark ? "gray.2" : "dark"}
                                >
                                  {total.toLocaleString("es-AR")}
                                </Table.Td>
                                <Table.Td ta="center" pr="xl">
                                  <Badge
                                    variant="light"
                                    color="cyan"
                                    size="lg"
                                  >
                                    {pct}%
                                  </Badge>
                                </Table.Td>
                              </Table.Tr>
                            );
                          }))}
                      <Table.Tr className={classes.totalRow}>
                        <Table.Td
                          pl="xl"
                          fw={800}
                          c={isDark ? "gray.1" : "dark"}
                        >
                          TOTAL
                        </Table.Td>
                        <Table.Td
                          ta="center"
                          fw={800}
                          c={isDark ? "gray.1" : "dark"}
                        >
                          {processedData.totalGeneral.toLocaleString("es-AR")}
                        </Table.Td>
                        <Table.Td ta="center" pr="xl">
                          <Badge color="cyan" variant="filled">
                            100%
                          </Badge>
                        </Table.Td>
                      </Table.Tr>
                    </Table.Tbody>
                  </Table>
                  <MapaReporte
                    data={data}
                    metadata={metadata}
                    columnasSeleccionadas={
                      variablePrincipal
                        ? [
                            variablePrincipal,
                            ...variablesExtra.map((v) => v.campo),
                          ]
                        : []
                    }
                    opcionesVariables={opcionesVariables}
                    resolverFK={resolverFK}
                    isDark={isDark}
                    municipiosCentroideCache={municipiosCentroideCache}
                  />
                </>
              )}
            </Stack>
          </Paper>
        </Grid.Col>
      </Grid>

      {/* Modal de exportación */}
      <Modal
        opened={openedExport}
        onClose={() => {
          setOpenedExport(false);
          setEmailEstado(null);
          setEmailDestino("");
          setEmailMensaje("");
        }}
        title={
          <Text fw={700} c={isDark ? undefined : "dark"}>
            Exportar reporte
          </Text>
        }
        centered
        size="md"
      >
        <Stack p="xs" gap="md">
          <Group grow>
            <Button
              leftSection={<IconFileDownload size={16} />}
              color="red"
              variant="light"
              onClick={() => {
                handleExportPDF();
                setOpenedExport(false);
              }}
            >
              PDF
            </Button>
            <Button
              leftSection={<IconPrinter size={16} />}
              color="gray"
              variant="light"
              onClick={() => {
                handlePrint();
                setOpenedExport(false);
              }}
            >
              Imprimir
            </Button>
          </Group>
          <Divider label="o enviar por email" labelPosition="center" />
          {emailEstado === "ok" && (
            <Alert icon={<IconCheck size={16} />} color="teal" variant="light">
              ¡Reporte enviado correctamente a{" "}
              <strong>{emailDestino || "destino"}</strong>!
            </Alert>
          )}
          {emailEstado === "error" && (
            <Alert
              icon={<IconAlertCircle size={16} />}
              color="red"
              variant="light"
            >
              No se pudo enviar el email. Revisá la dirección o intentá de
              nuevo.
            </Alert>
          )}
          <TextInput
            label="Dirección de email"
            placeholder="destinatario@ejemplo.com"
            value={emailDestino}
            onChange={(e) => {
              setEmailDestino(e.currentTarget.value);
              setEmailEstado(null);
            }}
            type="email"
            disabled={enviandoEmail}
          />
          <Textarea
            label="Mensaje (opcional)"
            placeholder="Escribí un mensaje para acompañar el reporte..."
            value={emailMensaje}
            onChange={(e) => setEmailMensaje(e.currentTarget.value)}
            minRows={3}
            maxRows={6}
            autosize
            disabled={enviandoEmail}
          />
          <Button
            leftSection={
              enviandoEmail ? (
                <Loader size={14} color="white" />
              ) : (
                <IconSend size={16} />
              )
            }
            color="teal"
            onClick={handleSendEmail}
            disabled={!emailDestino || enviandoEmail}
            loading={enviandoEmail}
            fullWidth
          >
            Enviar reporte
          </Button>
          <Text size="xs" c="dimmed">
            Se enviará como adjunto desde{" "}
            <strong>eco.datos.sot@gmail.com</strong>. Las respuestas llegarán a
            tu email.
          </Text>
        </Stack>
      </Modal>
    </Stack>
  );
}