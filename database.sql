-- AsistePY: datos iniciales, reglas de seguridad y conexión desde el navegador.
-- REQUISITO: ya existen public.perfiles y public.asistencias como en el ejercicio.
-- ANTES DE EJECUTAR: crear y confirmar estas 3 cuentas en Authentication > Users:
--   cajero@asistepy.test, asistente@asistepy.test, gerente@asistepy.test
-- No insertar directamente en auth.users: usar Supabase Auth.

-- 1) Poblar perfiles a partir de los UUID verdaderos de auth.users.
INSERT INTO public.perfiles (id, nombre, rol, horario_entrada, foto_url)
SELECT
  id,
  CASE email
    WHEN 'cajero@asistepy.test' THEN 'Camila Duarte'
    WHEN 'asistente@asistepy.test' THEN 'Tomás Rojas'
    WHEN 'gerente@asistepy.test' THEN 'Lucía González'
  END,
  CASE email
    WHEN 'cajero@asistepy.test' THEN 'Cajero'
    WHEN 'asistente@asistepy.test' THEN 'Asistente'
    WHEN 'gerente@asistepy.test' THEN 'Gerente'
  END,
  CASE email
    WHEN 'cajero@asistepy.test' THEN time '08:00'
    WHEN 'asistente@asistepy.test' THEN time '08:30'
    WHEN 'gerente@asistepy.test' THEN time '09:00'
  END,
  NULL
FROM auth.users
WHERE email IN ('cajero@asistepy.test','asistente@asistepy.test','gerente@asistepy.test')
ON CONFLICT (id) DO UPDATE
  SET nombre = excluded.nombre,
      rol = excluded.rol,
      horario_entrada = excluded.horario_entrada;

-- 2) Impedir dos asistencias del mismo empleado en la misma fecha.
CREATE UNIQUE INDEX IF NOT EXISTS asistencias_usuario_fecha_unica
ON public.asistencias (usuario_id, fecha);

-- 3) Datos de ejemplo para tres días anteriores (hora de Paraguay).
-- Se insertan antes del trigger que registra automáticamente las marcas reales.
WITH dias AS (
  SELECT (now() AT TIME ZONE 'America/Asuncion')::date - n AS fecha, n
  FROM generate_series(1,3) AS n
)
INSERT INTO public.asistencias(usuario_id, fecha, entrada, salida)
SELECT p.id, d.fecha,
       ((d.fecha + p.horario_entrada) AT TIME ZONE 'America/Asuncion')
       + CASE WHEN (p.rol='Cajero' AND d.n=1)
                  OR (p.rol='Asistente' AND d.n=2)
                  OR (p.rol='Gerente' AND d.n=3)
              THEN INTERVAL '12 minutes' ELSE INTERVAL '0 minutes' END,
       ((d.fecha + p.horario_entrada) AT TIME ZONE 'America/Asuncion')
       + INTERVAL '9 hours'
FROM public.perfiles p CROSS JOIN dias d
WHERE p.rol IN ('Cajero','Asistente','Gerente')
ON CONFLICT (usuario_id,fecha) DO NOTHING;

-- 4) Autorización: el gerente puede leer los perfiles y asistencias de todos.
-- Se usa una función de un esquema NO expuesto, para evitar recursión en RLS.
CREATE SCHEMA IF NOT EXISTS private;
CREATE OR REPLACE FUNCTION private.es_gerente()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.perfiles
    WHERE id = (SELECT auth.uid()) AND rol = 'Gerente'
  );
$$;
REVOKE ALL ON FUNCTION private.es_gerente() FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.es_gerente() TO authenticated;

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencias ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.perfiles FROM anon, authenticated;
REVOKE ALL ON TABLE public.asistencias FROM anon, authenticated;
GRANT SELECT ON TABLE public.perfiles TO authenticated;
GRANT UPDATE (foto_url) ON TABLE public.perfiles TO authenticated;
GRANT SELECT, INSERT ON TABLE public.asistencias TO authenticated;
GRANT UPDATE (salida) ON TABLE public.asistencias TO authenticated;

DROP POLICY IF EXISTS perfiles_lectura ON public.perfiles;
CREATE POLICY perfiles_lectura ON public.perfiles
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()) OR (SELECT private.es_gerente()));

DROP POLICY IF EXISTS perfiles_fotos_gerente ON public.perfiles;
CREATE POLICY perfiles_fotos_gerente ON public.perfiles
  FOR UPDATE TO authenticated
  USING ((SELECT private.es_gerente()))
  WITH CHECK ((SELECT private.es_gerente()));

DROP POLICY IF EXISTS asistencias_lectura ON public.asistencias;
CREATE POLICY asistencias_lectura ON public.asistencias
  FOR SELECT TO authenticated
  USING (usuario_id = (SELECT auth.uid()) OR (SELECT private.es_gerente()));

DROP POLICY IF EXISTS asistencias_insertar ON public.asistencias;
CREATE POLICY asistencias_insertar ON public.asistencias
  FOR INSERT TO authenticated
  WITH CHECK (usuario_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS asistencias_salida ON public.asistencias;
CREATE POLICY asistencias_salida ON public.asistencias
  FOR UPDATE TO authenticated
  USING (usuario_id = (SELECT auth.uid()) AND salida IS NULL)
  WITH CHECK (usuario_id = (SELECT auth.uid()));

-- 5) La fecha y la hora real las fija PostgreSQL, no el reloj del empleado.
CREATE OR REPLACE FUNCTION public.fijar_marca_asistencia()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.usuario_id := auth.uid();
    NEW.fecha := (now() AT TIME ZONE 'America/Asuncion')::date;
    NEW.entrada := now();
    NEW.salida := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.salida := now();
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.fijar_marca_asistencia() FROM PUBLIC;
DROP TRIGGER IF EXISTS trg_fijar_asistencia ON public.asistencias;
CREATE TRIGGER trg_fijar_asistencia
BEFORE INSERT OR UPDATE OF salida ON public.asistencias
FOR EACH ROW EXECUTE FUNCTION public.fijar_marca_asistencia();

-- 6) Fotos de perfil: bucket público de demostración; solo gerente puede subir.
-- No utilizar fotos personales reales en este prototipo público.
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('fotos-asistepy','fotos-asistepy',true,1048576,ARRAY['image/jpeg'])
ON CONFLICT (id) DO UPDATE
SET public=excluded.public,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

DROP POLICY IF EXISTS fotos_asistepy_subir_gerente ON storage.objects;
CREATE POLICY fotos_asistepy_subir_gerente ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'fotos-asistepy' AND (SELECT private.es_gerente()));

-- 7) Comprobación.
SELECT 'perfiles' AS tabla, COUNT(*) AS filas FROM public.perfiles
UNION ALL
SELECT 'asistencias', COUNT(*) FROM public.asistencias;
