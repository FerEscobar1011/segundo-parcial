-- AsistePY: LOGIN DIRECTO A TABLAS (SIN SUPABASE AUTH)
-- PROTOTIPO ACADÉMICO: usar solo datos ficticios.
-- Ejecutar completo en Supabase > SQL Editor > Run.
-- Reutiliza las dos tablas existentes (perfiles y asistencias).
-- IMPORTANTE: la clave '1234' es de PRUEBA. Los permisos anon son públicos.

-- Eliminar el comportamiento anterior dependiente de auth.uid().
DROP TRIGGER IF EXISTS trg_fijar_asistencia ON public.asistencias;
DROP FUNCTION IF EXISTS public.fijar_marca_asistencia();

-- Permitir perfiles independientes de auth.users.
ALTER TABLE public.perfiles DROP CONSTRAINT IF EXISTS perfiles_id_fkey;
ALTER TABLE public.perfiles ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS usuario text;
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS clave text;
CREATE UNIQUE INDEX IF NOT EXISTS perfiles_usuario_unico ON public.perfiles (usuario);

-- Crear los tres perfiles de demostración.
INSERT INTO public.perfiles (usuario, clave, nombre, rol, horario_entrada, foto_url) VALUES
  ('cajero',   '1234', 'Camila Duarte',   'Cajero',   '08:00', NULL),
  ('asistente','1234', 'Tomás Rojas',    'Asistente','08:30', NULL),
  ('gerente',  '1234', 'Lucía González',  'Gerente',  '09:00', NULL)
ON CONFLICT (usuario) DO UPDATE
SET clave = EXCLUDED.clave,
    nombre = EXCLUDED.nombre,
    rol = EXCLUDED.rol,
    horario_entrada = EXCLUDED.horario_entrada;

CREATE UNIQUE INDEX IF NOT EXISTS asistencias_usuario_fecha_unica
  ON public.asistencias (usuario_id, fecha);

-- Datos de ejemplo de los tres últimos días, una sola vez por empleado y fecha.
WITH dias AS (
  SELECT (now() AT TIME ZONE 'America/Asuncion')::date - n AS fecha, n
  FROM generate_series(1,3) AS n
)
INSERT INTO public.asistencias(usuario_id, fecha, entrada, salida)
SELECT p.id, d.fecha,
       ((d.fecha + p.horario_entrada) AT TIME ZONE 'America/Asuncion')
         + CASE WHEN (p.usuario='cajero' AND d.n=1)
                    OR (p.usuario='asistente' AND d.n=2)
                    OR (p.usuario='gerente' AND d.n=3)
                THEN INTERVAL '12 minutes' ELSE INTERVAL '0 minutes' END,
       ((d.fecha + p.horario_entrada) AT TIME ZONE 'America/Asuncion') + INTERVAL '9 hours'
FROM public.perfiles p CROSS JOIN dias d
WHERE p.usuario IN ('cajero','asistente','gerente')
ON CONFLICT (usuario_id,fecha) DO NOTHING;

-- Login directo a 'perfiles' mediante una función SQL.
-- No expone la columna 'clave' al navegador mediante SELECT.
-- El control real de acceso a filas NO está garantizado en esta demo pública.
CREATE OR REPLACE FUNCTION public.login_demo(p_usuario text, p_clave text)
RETURNS TABLE(
  id uuid,
  nombre varchar(100),
  rol varchar(20),
  horario_entrada time without time zone,
  foto_url text
)
LANGUAGE sql SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p.id, p.nombre, p.rol, p.horario_entrada, p.foto_url
  FROM public.perfiles p
  WHERE p.usuario = p_usuario AND p.clave = p_clave
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.login_demo(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_demo(text,text) TO anon;

-- Registrar siempre fecha y hora del servidor en las marcas reales.
CREATE OR REPLACE FUNCTION public.marca_hora_demo()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.fecha := (now() AT TIME ZONE 'America/Asuncion')::date;
    NEW.entrada := now();
    NEW.salida := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.salida := now();
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_marca_hora_demo ON public.asistencias;
CREATE TRIGGER trg_marca_hora_demo
BEFORE INSERT OR UPDATE OF salida ON public.asistencias
FOR EACH ROW EXECUTE FUNCTION public.marca_hora_demo();

-- Quitar las políticas antiguas que requerían Supabase Auth.
DROP POLICY IF EXISTS perfiles_lectura ON public.perfiles;
DROP POLICY IF EXISTS perfiles_fotos_gerente ON public.perfiles;
DROP POLICY IF EXISTS asistencias_lectura ON public.asistencias;
DROP POLICY IF EXISTS asistencias_insertar ON public.asistencias;
DROP POLICY IF EXISTS asistencias_salida ON public.asistencias;

-- DEMO PÚBLICA: todos los visitantes comparten el rol anon.
-- Las políticas abiertas permiten usar GitHub Pages sin Auth.
-- No utilizar con datos o fotos personales reales.
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencias ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.perfiles FROM anon, authenticated;
REVOKE ALL ON TABLE public.asistencias FROM anon, authenticated;

GRANT SELECT (id, usuario, nombre, rol, horario_entrada, foto_url) ON public.perfiles TO anon;
GRANT UPDATE (foto_url) ON public.perfiles TO anon;
GRANT SELECT, INSERT ON public.asistencias TO anon;
GRANT UPDATE (salida) ON public.asistencias TO anon;

DROP POLICY IF EXISTS demo_perfiles_leer ON public.perfiles;
CREATE POLICY demo_perfiles_leer ON public.perfiles FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS demo_perfiles_foto ON public.perfiles;
CREATE POLICY demo_perfiles_foto ON public.perfiles FOR UPDATE TO anon
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS demo_asistencias_leer ON public.asistencias;
CREATE POLICY demo_asistencias_leer ON public.asistencias FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS demo_asistencias_insertar ON public.asistencias;
CREATE POLICY demo_asistencias_insertar ON public.asistencias FOR INSERT TO anon WITH CHECK (true);
DROP POLICY IF EXISTS demo_asistencias_salida ON public.asistencias;
CREATE POLICY demo_asistencias_salida ON public.asistencias FOR UPDATE TO anon
  USING (true) WITH CHECK (true);

-- Resultados esperados: 3 usuarios de demo; 9 asistencias de ejemplo.
SELECT usuario, nombre, rol, horario_entrada
FROM public.perfiles
WHERE usuario IN ('cajero','asistente','gerente')
ORDER BY usuario;

SELECT COUNT(*) AS asistencias_de_ejemplo
FROM public.asistencias
WHERE usuario_id IN (
  SELECT id FROM public.perfiles
  WHERE usuario IN ('cajero','asistente','gerente')
);
