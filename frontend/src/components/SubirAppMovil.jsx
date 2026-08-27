import { useEffect, useState } from "react";
import {
  Modal,
  Stack,
  Group,
  Text,
  TextInput,
  Textarea,
  FileInput,
  Button,
  ThemeIcon,
  Alert,
} from "@mantine/core";
import { IconUpload, IconApps, IconInfoCircle } from "@tabler/icons-react";
import { notifications } from "@mantine/notifications";
import { supabase } from "../lib/supabase";

// Una sola app para todo el sistema. El slug es fijo (la tabla mobile_apps lo
// necesita NOT NULL, pero ya no distinguimos "plan del fuego" / "EcoAlerta").
const APP_SLUG = "ecodatos";
const APK_MIME = "application/vnd.android.package-archive";

export default function SubirAppMovil({ opened, onClose, onSuccess, appActual }) {
  const [file, setFile] = useState(null);
  const [nombre, setNombre] = useState("EcoDatos");
  const [version, setVersion] = useState("");
  const [descripcion, setDescripcion] = useState("");
  const [subiendo, setSubiendo] = useState(false);

  // Prefill con la versión activa cada vez que se abre.
  useEffect(() => {
    if (!opened) return;
    setFile(null);
    setNombre(appActual?.nombre || "EcoDatos");
    setVersion("");
    setDescripcion(appActual?.descripcion || "");
  }, [opened, appActual]);

  const versionLimpia = version.trim().replace(/[^0-9A-Za-z._-]/g, "");
  const puedeSubir =
    !!file && nombre.trim().length > 0 && versionLimpia.length > 0 && !subiendo;

  const handleSubmit = async () => {
    if (!puedeSubir) return;
    setSubiendo(true);
    try {
      const apkPath = `${APP_SLUG}/ecodatos-v${versionLimpia}.apk`;

      // 1. Subir el APK al bucket (upsert por si se re-sube la misma versión).
      const { error: upErr } = await supabase.storage
        .from("apks")
        .upload(apkPath, file, { contentType: APK_MIME, upsert: true });
      if (upErr) throw new Error(`No se pudo subir el archivo: ${upErr.message}`);

      // 2. Insertar la fila nueva como activa.
      const { data: nueva, error: insErr } = await supabase
        .from("mobile_apps")
        .insert({
          formulario_slug: APP_SLUG,
          nombre: nombre.trim(),
          version: versionLimpia,
          descripcion: descripcion.trim() || null,
          apk_path: apkPath,
          activo: true,
        })
        .select()
        .single();
      if (insErr) throw new Error(`No se pudo registrar la versión: ${insErr.message}`);

      // 3. Desactivar las versiones anteriores.
      const { error: deErr } = await supabase
        .from("mobile_apps")
        .update({ activo: false })
        .eq("activo", true)
        .neq("id", nueva.id);
      if (deErr) {
        // La versión nueva ya quedó activa; solo avisamos.
        console.error("No se pudieron desactivar versiones anteriores:", deErr);
      }

      notifications.show({
        title: "Versión publicada",
        message: `${nombre.trim()} v${versionLimpia} ya está disponible para descargar.`,
        color: "green",
      });
      onSuccess?.();
    } catch (err) {
      console.error(err);
      notifications.show({
        title: "Error al subir la app",
        message: err.message || "Ocurrió un error inesperado.",
        color: "red",
      });
    } finally {
      setSubiendo(false);
    }
  };

  return (
    <Modal
      opened={opened}
      onClose={subiendo ? () => {} : onClose}
      centered
      radius="lg"
      lockScroll={false}
      closeOnClickOutside={!subiendo}
      withCloseButton={!subiendo}
      overlayProps={{ backgroundOpacity: 0.7, blur: 8 }}
      title={
        <Group gap="xs">
          <ThemeIcon variant="light" color="green.6" size="lg" radius="md">
            <IconApps size={20} />
          </ThemeIcon>
          <Text fw={800} lts="0.5px">
            SUBIR NUEVA VERSIÓN
          </Text>
        </Group>
      }
    >
      <Stack gap="md">
        <FileInput
          label="Archivo APK"
          placeholder="Seleccioná el .apk"
          accept={`.apk,${APK_MIME}`}
          leftSection={<IconUpload size={16} />}
          value={file}
          onChange={setFile}
          required
          clearable
        />

        <TextInput
          label="Nombre"
          placeholder="EcoDatos"
          value={nombre}
          onChange={(e) => setNombre(e.currentTarget.value)}
          required
        />

        <TextInput
          label="Versión"
          placeholder="1.0.1"
          description="Solo números, letras y . _ -"
          value={version}
          onChange={(e) => setVersion(e.currentTarget.value)}
          required
        />

        <Textarea
          label="Descripción"
          placeholder="Novedades de esta versión (opcional)"
          autosize
          minRows={2}
          maxRows={5}
          value={descripcion}
          onChange={(e) => setDescripcion(e.currentTarget.value)}
        />

        {file && versionLimpia && (
          <Alert
            variant="light"
            color="gray"
            icon={<IconInfoCircle size={16} />}
            p="xs"
          >
            <Text size="xs">
              Se guardará como <code>apks/{APP_SLUG}/ecodatos-v{versionLimpia}.apk</code> y
              se desactivará la versión anterior.
            </Text>
          </Alert>
        )}

        <Button
          color="green.7"
          fullWidth
          size="md"
          radius="md"
          leftSection={<IconUpload size={16} />}
          loading={subiendo}
          disabled={!puedeSubir}
          onClick={handleSubmit}
          mt="xs"
          style={{ fontWeight: 800 }}
        >
          {subiendo ? "SUBIENDO..." : "PUBLICAR VERSIÓN"}
        </Button>
      </Stack>
    </Modal>
  );
}
