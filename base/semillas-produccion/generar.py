# Genera base/semillas-produccion/003_turnos_consultas.sql y 008_resenas.sql: seis meses de una
# clínica que cierra por todos lados (cada vacuna dada sale de una consulta, en el orden del plan y con
# los días mínimos entre dosis; cada consulta con su factura; las reseñas, de clientes atendidos).
# Las fechas son relativas al día de la carga: el pasado lejano a @lunes (el lunes de esta semana, así
# se sabe qué día de la semana es cada turno) y los próximos días a @hoy.
import random, io, os

G = os.path.dirname(os.path.abspath(__file__)) + '/'
R = random.Random(20261126)

# ---------- Las mascotas (las mismas fórmulas que 001) ----------
NOMBRES = ['Toby', 'Mora', 'Coco', 'Lola', 'Rocky', 'Nala', 'Bobby', 'Kira', 'Max', 'Mía',
           'Thor', 'Frida', 'Bruno', 'Olivia', 'Zeus', 'Pelusa', 'Tango', 'Uma', 'Ramón', 'Chispa',
           'Oreo', 'Manchita', 'Pancho', 'Luz', 'Duque', 'Canela', 'Milo', 'Sasha', 'Pipo', 'Greta',
           'Simón', 'Brisa', 'Fermín', 'Nina', 'Tobías', 'Lila', 'Felipe', 'Matilda', 'Benito', 'Bella',
           'Jazmín', 'Roco', 'Kiara', 'Lucho', 'Malena', 'Dante', 'Pupi', 'Ciro', 'Maya', 'Hércules',
           'Luna', 'Rufo', 'Clara', 'Gordo', 'Paloma', 'Indio', 'Lupe', 'Moro', 'Tita', 'Bambi',
           'Sultán', 'Copito', 'Rita', 'Panchito', 'Fiona', 'Negro', 'Cleo', 'Bigote', 'Nube', 'Teo',
           'Frodo', 'Melón', 'Juana', 'Atilio', 'Pochi', 'Vito', 'Cachi', 'Rubia', 'Salvador', 'Cuca']

def edad_dias_fondo(i):
    # 001: fecha_nacimiento = @hoy - INTERVAL edad DAY
    return (5 + (i * 17) % 150) * 30 + (i * 7) % 28

MASCOTAS = {}
for i in range(1, 81):
    MASCOTAS[30000 + i] = dict(nombre=NOMBRES[i - 1], especie='GATO' if i % 3 == 0 else 'PERRO',
                               duenio=3001 + (i - 1) // 2, edad=edad_dias_fondo(i))
DEMO_EDAD = {30081: 4 * 365 + 90, 30082: 2 * 365 + 213, 30083: 9 * 365 + 30, 30084: 426}
for mid, (nom, esp) in {30081: ('Rocco', 'PERRO'), 30082: ('Mishi', 'GATO'), 30083: ('Coco', 'PERRO'), 30084: ('Lola', 'PERRO')}.items():
    MASCOTAS[mid] = dict(nombre=nom, especie=esp, duenio=None, edad=DEMO_EDAD[mid])

# Plan sanitario (ids de la migración 005 y 025).
PLAN = {
    'PERRO': {'desp': 1, 'S1': 2, 'S2': 3, 'S3': 4, 'anti': 5, 'Sref': 6, 'tos': 13},
    'GATO': {'desp': 7, 'S1': 8, 'S2': 9, 'anti': 10, 'Sref': 11},
}
NOMBRE_PLAN = {1: 'Desparasitación interna', 2: 'Séxtuple (1.ª dosis)', 3: 'Séxtuple (2.ª dosis)', 4: 'Séxtuple (3.ª dosis)',
               5: 'Antirrábica', 6: 'Séxtuple (refuerzo anual)', 7: 'Desparasitación interna', 8: 'Triple felina (1.ª dosis)',
               9: 'Triple felina (2.ª dosis)', 10: 'Antirrábica', 11: 'Triple felina (refuerzo anual)', 13: 'Tos de las perreras'}
TIPO_PLAN = {p: ('DESPARASITACION' if p in (1, 7) else 'VACUNA') for p in NOMBRE_PLAN}
# Insumo de cada ítem del plan (002 de producción; 3016: antiparasitario interno).
INSUMO_PLAN = {1: 3016, 7: 3016, 2: 3009, 3: 3009, 4: 3009, 6: 3009, 8: 3010, 9: 3010, 11: 3010, 5: 3011, 10: 3011, 13: 3012}

DIAG = [  # (diagnóstico, indicaciones, producto perro, producto gato)
    ('Control general: sano, peso adecuado.', None, None, None),
    ('Otitis externa leve.', 'Limpieza y gotas óticas por 7 días.', None, None),
    ('Gastroenteritis leve: vómitos y diarrea de 48 horas.', 'Dieta blanda por 3 días e hidratación. Volver si no mejora.', None, None),
    ('Dermatitis alérgica por picadura de pulga.', 'Antiparasitario externo mensual y antiinflamatorio por 5 días.', 3005, 3001),
    ('Control de peso: sobrepeso leve.', 'Reducir la ración un 15 % y más paseos. Control en 30 días.', None, None),
    ('Conjuntivitis bacteriana.', 'Colirio antibiótico cada 8 horas por 7 días.', 3020, 3020),
    ('Cojera leve del miembro posterior izquierdo, sin fractura.', 'Reposo y antiinflamatorio por 5 días. Si sigue, radiografía.', 3019, None),
    ('Sarro dental moderado y gingivitis.', 'Se sugiere limpieza dental con anestesia.', None, None),
    ('Parásitos intestinales.', 'Antiparasitario interno y repetir en 15 días.', 3009, 3021),
]

# ---------- La agenda ----------
HORAS = ['%02d:%02d:00' % (9 + (j * 30 + 15) // 60, (j * 30 + 15) % 60) for j in range(20)]   # 9:15 a 18:45
ocupado = {}            # (base, día) -> set de índices de hora
turnos = []             # cada uno: dict
pendientes = []         # eventos sin dar: (mascota, plan, base, día, turno o None)
sig_turno = [30001]

def dia_semana(base, d):
    return d % 7 if base == 'L' else None   # 0 = lunes

def libre(base, d, tarde_lunes=False):
    usados = ocupado.setdefault((base, d), set())
    if base == 'L' and d % 7 == 6:
        return None
    if len(usados) >= 7:
        return None
    opciones = [j for j in range(20) if j not in usados and not (base == 'L' and d % 7 == 0 and j >= 10 and not tarde_lunes)]
    if not opciones:
        return None
    j = R.choice(opciones)
    usados.add(j)
    return j

def agendar(mascota, base, d, motivos, estado='ATENDIDO', diag=None, obs=None, insumos=(), productos=(), dar=(), hora=None, mover=True):
    """motivos: [(motivo, plan)] ; dar: planes que quedan dados en la consulta."""
    while True:
        j = libre(base, d) if hora is None else hora
        if j is not None:
            break
        if not mover:
            raise SystemExit(f'sin lugar {mascota} {base} {d}')
        d += 1
    if hora is not None:
        ocupado.setdefault((base, d), set()).add(j)
    t = dict(id=sig_turno[0], mascota=mascota, base=base, dia=d, hora=HORAS[j] if isinstance(j, int) else j, motivos=list(motivos),
             estado=estado, diag=diag, obs=obs, insumos=list(insumos), productos=list(productos), dar=list(dar))
    sig_turno[0] += 1
    turnos.append(t)
    return t

CADENA_P = {2: 'S', 3: 'S', 4: 'S', 6: 'S', 8: 'T', 9: 'T', 11: 'T'}
dadas_por = {}   # mascota -> [(día de @lunes o día de @hoy + 99999, plan)]

def minimo(p, q):
    if p in (5, 10, 13):
        return 330
    if p in (1, 7):
        return 14
    return 330 if (p in (6, 11) and q in (6, 11)) else 21

def cumple(mascota, d, p):
    for dq, q in dadas_por.get(mascota, []):
        misma = (q == p) or (p in CADENA_P and CADENA_P.get(q) == CADENA_P[p])
        if misma and abs(d - dq) < minimo(p, q) + 2:
            return False
    return True

def vacunacion(mascota, base, d, planes, extra_motivos=(), flexible=False):
    """Una visita en la que se dan esos ítems del plan (con su insumo y una jeringa). Con flexible, si
    alguna dosis no respeta los días mínimos con las ya dadas, prueba otro día de la ventana."""
    clave = d if base == 'L' else d + 99999
    if not all(cumple(mascota, clave, p) for p in planes):
        if not flexible:
            raise SystemExit(f'días mínimos: {mascota} {planes} {d}')
        for _ in range(200):
            d = R.randint(LUNES_MIN + 3, LUNES_MAX - 3)
            if all(cumple(mascota, d, p) for p in planes):
                break
        else:
            return None
        clave = d
    dadas_por.setdefault(mascota, []).extend((clave, p) for p in planes)
    m = MASCOTAS[mascota]
    nombres = [NOMBRE_PLAN[p] for p in planes]
    vac = [p for p in planes if TIPO_PLAN[p] == 'VACUNA']
    motivos = [('VACUNACION' if TIPO_PLAN[p] == 'VACUNA' else 'DESPARASITACION', p) for p in planes] + list(extra_motivos)
    insumos = [(INSUMO_PLAN[p], 1) for p in planes] + ([(3001, len(vac))] if vac else [])
    diag = 'Aplicación de ' + ' y '.join(n[0].lower() + n[1:] for n in nombres) + '.'
    obs = 'Sin reacciones. Próxima dosis según el calendario.'
    return agendar(mascota, base, d, motivos, diag=diag, obs=obs, insumos=insumos, dar=planes)

def consulta(mascota, base, d, k=None, motivo='CONSULTA', hora=None):
    m = MASCOTAS[mascota]
    k = R.randrange(len(DIAG)) if k is None else k
    diag, obs, pp, pg = DIAG[k]
    prod = pp if m['especie'] == 'PERRO' else pg
    ins = [(3004, 1)] + ([(3005, 1)] if R.random() < 0.35 else [])
    return agendar(mascota, base, d, [(motivo, None)], diag=diag, obs=obs, insumos=ins,
                   productos=[(prod, 1)] if prod else [], hora=hora)

LUNES_MIN, LUNES_MAX = -182, -8      # pasado seguro: @lunes + d (siempre antes de hoy - 1)

# --- Mascotas de fondo: su historia en los últimos seis meses ---
tiene_antirrabica = set()
for mid in range(30001, 30081):
    m = MASCOTAS[mid]
    esp, plan = m['especie'], PLAN[m['especie']]
    nac = -m['edad'] - 7          # nacimiento en días respecto de @lunes, con margen de una semana
    visitas = []
    # Cachorros: la serie inicial dentro de la ventana (a las 6, 9, 12 y 16 semanas).
    if nac + 42 >= LUNES_MIN:
        if esp == 'PERRO':
            serie = [(42, [plan['S1'], plan['desp']]), (66, [plan['S2']]), (90, [plan['S3']]), (118, [plan['anti']])]
        else:
            serie = [(56, [plan['S1'], plan['desp']]), (84, [plan['S2']]), (118, [plan['anti']])]
        for edad, planes in serie:
            d = nac + edad
            if LUNES_MIN <= d <= LUNES_MAX:
                vacunacion(mid, 'L', d, planes)
                if plan['anti'] in planes:
                    tiene_antirrabica.add(mid)
    else:
        # Adultos: la antirrábica anual a la mitad, la desparasitación y, a algunos perros, la tos de las perreras.
        if mid % 2 == 0:
            vacunacion(mid, 'L', R.randint(LUNES_MIN + 5, LUNES_MAX - 5), [plan['anti']] + ([plan['desp']] if R.random() < 0.5 else []), flexible=True)
            tiene_antirrabica.add(mid)
        if esp == 'PERRO' and mid % 5 == 1:
            vacunacion(mid, 'L', R.randint(LUNES_MIN + 5, LUNES_MAX - 5), [plan['tos']], flexible=True)
        if mid % 3 == 1:
            vacunacion(mid, 'L', R.randint(LUNES_MIN + 5, -100), [plan['desp']], flexible=True)
    # Consultas: de 2 a 4 en seis meses.
    for _ in range(R.randint(2, 4)):
        consulta(mid, 'L', R.randint(LUNES_MIN, LUNES_MAX))

# Castraciones (con su control a los 10 días), una cirugía y una urgencia un sábado.
for mid, d in [(30068, -48), (30015, -120), (30041, -75), (30052, -150)]:   # 30068: Bigote, de Lautaro
    agendar(mid, 'L', d, [('CASTRACION', None)], diag='Castración programada sin complicaciones.',
            obs='Collar isabelino y antiinflamatorio por 5 días. Control en 10 días.', insumos=[(3004, 2), (3005, 4), (3013, 1), (3014, 1)])
    agendar(mid, 'L', d + 10, [('CONTROL', None)], diag='Control posquirúrgico de castración: buena cicatrización.',
            obs='Retirar los puntos en 3 días.', insumos=[(3004, 1), (3005, 1)])
agendar(30040, 'L', -96, [('CIRUGIA', None)], diag='Extracción de un cuerpo extraño (juguete) del estómago.',
        obs='Dieta blanda por 5 días. Control en 7 días.', insumos=[(3004, 2), (3005, 4), (3013, 1), (3014, 2)])
agendar(30040, 'L', -89, [('CONTROL', None)], diag='Control posquirúrgico: buena evolución.', obs=None, insumos=[(3004, 1)])
sabado = next(d for d in range(-70, -60) if d % 7 == 5)
agendar(30054, 'L', sabado, [('URGENCIA', None)], diag='Intoxicación leve por ingesta de chocolate.',          # Paloma, de Belén
        obs='Lavaje y observación por 4 horas. Dieta blanda por 2 días.', insumos=[(3004, 1), (3014, 1)])

# Turnos que no se atendieron: algunos cancelados y ausentes (sin consulta).
for _ in range(22):
    mid = R.randint(30001, 30080)
    agendar(mid, 'L', R.randint(LUNES_MIN, LUNES_MAX), [('CONSULTA', None)], estado=R.choice(['CANCELADO', 'AUSENTE']))
# Los lunes a la tarde, casi sin turnos (la franja que Reportes sugiere promocionar): unos cancelados.
for d in range(LUNES_MIN, LUNES_MAX):
    if d % 7 == 0 and R.random() < 0.4:
        j = 10 + R.randrange(10)
        if j not in ocupado.setdefault(('L', d), set()):
            agendar(R.randint(30001, 30080), 'L', d, [('CONSULTA', None)], estado='CANCELADO', hora=j)

# --- Las mascotas de la demo: su historia desde cachorros (hace años) ---
def demo(mid, eventos, consultas_extra=()):
    nac = -MASCOTAS[mid]['edad'] - 3
    for d, planes in eventos:
        dd = d
        while dd % 7 == 6:
            dd -= 1
        vacunacion(mid, 'L', dd, planes)
    for d, k in consultas_extra:
        dd = d
        while dd % 7 == 6:
            dd -= 1
        consulta(mid, 'L', dd, k)

# Rocco (perro, 4 años): serie de cachorro, refuerzos anuales y antirrábicas; la última hace un año.
n = -DEMO_EDAD[30081]
demo(30081, [(n + 42, [2, 1]), (n + 66, [3]), (n + 90, [4]), (n + 118, [5]),
             (n + 400, [6]), (n + 500, [5]), (n + 770, [6]), (n + 865, [5]), (-335, [6]), (-345, [5])],
     [(n + 620, 0), (n + 1010, 3)])
# Mishi (gata, 2 años y medio): al día; triple felina hace dos meses.
n = -DEMO_EDAD[30082]
demo(30082, [(n + 56, [8, 7]), (n + 84, [9]), (n + 118, [10]), (n + 420, [11]), (n + 490, [10]), (-64, [11]), (-100, [10, 7])],
     [(n + 300, 5)])
# Coco (caniche de 9 años): serie de cachorro hace años y los últimos refuerzos; la séxtuple vence ahora.
n = -DEMO_EDAD[30083]
demo(30083, [(n + 42, [2, 1]), (n + 66, [3]), (n + 90, [4]), (n + 118, [5]), (-760, [6]), (-700, [5]), (-400, [6]), (-310, [5])],
     [(-560, 7), (-250, 4)])
# Lola (beagle de 14 meses): serie de cachorro, antirrábica y el refuerzo de la séxtuple hace dos meses.
n = -DEMO_EDAD[30084]
demo(30084, [(n + 42, [2, 1]), (n + 66, [3]), (n + 90, [4]), (n + 118, [5]), (-62, [6])], [(-200, 2)])
# Rocco: otitis hace unas semanas; Coco: control de senior hace unos días (pasado reciente, @lunes).
agendar(30081, 'L', -20 if -20 % 7 != 6 else -21, [('CONSULTA', None)], diag='Otitis externa en el oído derecho, con secreción y picazón.',
        obs='Limpieza de oído y gotas óticas cada 12 horas por 7 días. Control en 15 días.', insumos=[(3004, 1), (3005, 1)])
agendar(30083, 'L', -10 if -10 % 7 != 6 else -11, [('CONTROL', None)], diag='Control de senior: buen estado general. Sarro moderado y leve soplo, a controlar.',
        obs='Se sugiere limpieza dental programada y ecocardiograma de control.', insumos=[(3004, 1)])

# Lo que viene de la demo (respecto de @hoy; si cae domingo, el lunes): Rocco se vacuna en 3 días
# (antirrábica, ya en el calendario); Lola tiene consulta en 5. Calendarios: lo pendiente.
t_rocco = agendar(30081, 'H', 3, [('VACUNACION', 5)], estado='PROGRAMADO', hora=19 * 0 + 0, mover=False)
t_rocco['hora'] = '19:20:00'
t_lola = agendar(30084, 'H', 5, [('CONSULTA', None)], estado='PROGRAMADO', hora=0, mover=False)
t_lola['hora'] = '19:50:00'
pendientes += [
    (30081, 5, 'H', 3, t_rocco['id']),          # Rocco: antirrábica (con su turno)
    (30081, 1, 'H', -14, None),                 # Rocco: desparasitación vencida
    (30082, 10, 'H', 265, None),                # Mishi: antirrábica
    (30082, 7, 'H', 30, None),                  # Mishi: desparasitación
    (30083, 6, 'H', -30, None),                 # Coco: séxtuple vencida
    (30083, 5, 'H', 60, None),                  # Coco: antirrábica
    (30084, 5, 'H', 25, None),                  # Lola: antirrábica
]

# Antirrábicas de mascotas de fondo que vencen en los próximos días (el motor avisa las de 7 días):
# las que no se dieron la antirrábica en estos meses. A algunas ya se les dio turno para ese día.
candidatas = [mid for mid in range(30001, 30081) if mid not in tiene_antirrabica and MASCOTAS[mid]['edad'] > 200]
R.shuffle(candidatas)
for k, mid in enumerate(candidatas[:24]):
    dia = k % 10
    t = None
    if k < 6 and dia >= 1:
        t = agendar(mid, 'H', dia, [('VACUNACION', PLAN[MASCOTAS[mid]['especie']]['anti'])], estado='PROGRAMADO')
    pendientes.append((mid, PLAN[MASCOTAS[mid]['especie']]['anti'], 'H', dia, t['id'] if t else None))

# Los próximos días (respecto de @hoy): hoy, la mitad atendidos; los días que vienen, programados;
# la semana pasada, atendidos. Consultas comunes.
for k in range(-6, 10):
    for _ in range(3 if k != 0 else 6):
        mid = R.randint(30001, 30080)
        if k < 0 or k == 0 and len([t for t in turnos if t['base'] == 'H' and t['dia'] == 0 and t['estado'] == 'ATENDIDO']) < 3:
            consulta(mid, 'H', k)
        else:
            agendar(mid, 'H', k, [(R.choice(['CONSULTA', 'CONTROL']), None)], estado='PROGRAMADO')

# Nala (gata de Camila): conjuntivitis hace unos días (la reseña 1 es de hace 2).
consulta(30006, 'H', -5, 5)

assert sig_turno[0] <= 30761, sig_turno[0]

# ---------- Reseñas (008): de clientes atendidos antes de escribirlas ----------
RESENAS = [  # (autor 3000 + n, estrellas, hace cuántos días, texto, respuesta)
    (3, 5, 2, 'Llevé a mi gata por una conjuntivitis y en dos días estaba bien. Muy buena atención y me explicaron todo.', '¡Gracias, Camila! Nos alegra que Nala se haya recuperado tan rápido.'),
    (12, 5, 5, 'Coordiné el turno por WhatsApp y me atendieron en el horario. Puntuales y muy amables.', None),
    (21, 4, 8, 'Buena atención y precios razonables. A veces hay que esperar un poco en la sala.', 'Gracias por el comentario, Valeria. Estamos ajustando los turnos para que la espera sea menor.'),
    (7, 5, 11, 'Me encanta poder ver las vacunas de mis perros en el sitio. Ya no me olvido ninguna.', None),
    (30, 5, 15, 'Compré por la página y lo retiré en el local. Súper práctico.', '¡Gracias, Emiliano! Te esperamos en la próxima compra.'),
    (17, 3, 19, 'La atención está bien, pero el día que fui se demoraron casi media hora con el turno.', 'Rocío, perdón por la demora: ese día tuvimos una urgencia. Gracias por avisarnos.'),
    (25, 5, 10, 'Adoptamos a nuestro gato gracias a un refugio que publica acá. Nos acompañaron en todo el proceso.', None),
    (9, 4, 27, 'Muy buena la doctora, se nota que quiere a los animales. Le pondría 5 si hubiera más turnos a la tarde.', None),
    (34, 5, 31, 'Castraron a mi perro y el seguimiento fue excelente. En el control quedó todo perfecto.', 'Gracias, Lautaro. Que Bigote siga muy bien.'),
    (2, 2, 36, 'El producto que quería no tenía stock y tuve que volver otro día.', 'Bruno, gracias por avisar. Ahora la página muestra el stock de cada producto antes de comprar.'),
    (39, 5, 40, 'Excelente atención. Mi gato es muy arisco y lo trataron con muchísima paciencia.', None),
    (14, 4, 46, 'Buenos precios en la tienda y te avisan cuando el pedido está listo.', None),
    (27, 5, 52, 'Atendieron a mi perra de urgencia un sábado. Les estoy muy agradecida.', 'Gracias, Belén. Para eso estamos.'),
    (5, 3, 58, 'Bien en general. Me hubiera gustado que me expliquen un poco más el tratamiento.', None),
    (36, 5, 64, 'Muy buena veterinaria. Llevo a mis dos mascotas y siempre las atienden con cariño.', '¡Gracias, Nicolás! Es un gusto atenderlos.'),
    (19, 4, 70, 'Muy prolijo todo: la factura queda guardada en la cuenta.', None),
    (31, 5, 77, 'Me avisaron que le tocaba la antirrábica a mi mascota y fui ese mismo día. Un golazo.', None),
    (10, 5, 85, 'Atención cálida y profesional. Mi perro sale contento, que ya es mucho decir.', 'Gracias, Joaquín. ¡Saludos a Ramón!'),
    (23, 4, 93, 'Buena experiencia. El lugar es chico pero está muy limpio.', None),
    (6, 5, 101, 'Me ayudaron a elegir el alimento correcto para mi perro. Muy recomendables.', '¡Gracias, Federico! Cualquier duda con la alimentación, consultanos.'),
    (28, 4, 110, 'Buena atención. El estacionamiento en la zona es complicado.', None),
    (15, 5, 118, 'Siempre atentos. Se nota que les importan los animales.', None),
]
# Cada autor tuvo una consulta atendida al menos 4 días antes de su reseña (respecto de @lunes, con
# una semana de margen). Si no la tiene, se le agrega.
def atendidas(duenio):
    return [t for t in turnos if MASCOTAS[t['mascota']]['duenio'] == duenio and t['estado'] == 'ATENDIDO']
for n, _, dias, texto, _ in RESENAS:
    duenio = 3000 + n
    limite = -dias - 4
    ok = [t for t in atendidas(duenio) if (t['dia'] if t['base'] == 'L' else t['dia'] - 7) <= limite - 7]
    if 'antirrábica' in texto:
        ok = [t for t in ok if any(p in (5, 10) for p in t['dar'])]
    if 'urgencia' in texto:
        ok = [t for t in ok if t['motivos'][0][0] == 'URGENCIA']
    if 'Castraron' in texto:
        ok = [t for t in ok if t['motivos'][0][0] == 'CASTRACION']
    if 'conjuntivitis' in texto:
        ok = [t for t in atendidas(duenio) if t['diag'] == DIAG[5][0]]
    if 'vacunas de mis perros' in texto:
        ok = [t for t in ok if t['dar']]
    if not ok:
        mid = 3000 + 0  # se busca una mascota del autor
        mid = next(m for m, v in MASCOTAS.items() if v['duenio'] == duenio)
        d = limite - 10
        while d % 7 == 6:
            d -= 1
        if 'antirrábica' in texto or 'vacunas' in texto:
            hecho = None
            for mid2 in [m for m, v in MASCOTAS.items() if v['duenio'] == duenio]:
                p2 = PLAN[MASCOTAS[mid2]['especie']]['anti' if 'antirrábica' in texto else 'desp']
                for d2 in range(d, LUNES_MIN, -1):
                    if d2 % 7 != 6 and cumple(mid2, d2, p2):
                        hecho = vacunacion(mid2, 'L', d2, [p2])
                        break
                if hecho:
                    break
            assert hecho, (duenio, texto)
        else:
            consulta(mid, 'L', d, 0)
assert sig_turno[0] <= 30761, sig_turno[0]

# ---------- Controles de las reglas del calendario (antes de escribir nada) ----------
def fecha_rel_hoy(t):     # en días respecto de @hoy, en el peor caso (@lunes = @hoy - 6)
    return t['dia'] - 6 if t['base'] == 'L' else t['dia']
por_mascota = {}
for t in turnos:
    if t['estado'] == 'ATENDIDO':
        for p in t['dar']:
            por_mascota.setdefault(t['mascota'], []).append((t['dia'] if t['base'] == 'L' else t['dia'] + 99999, p, t))
ORDEN = {2: 1, 3: 2, 4: 3, 6: 4, 8: 1, 9: 2, 11: 3}
CADENA = {2: 'S', 3: 'S', 4: 'S', 6: 'S', 8: 'T', 9: 'T', 11: 'T'}
for mid, dadas in por_mascota.items():
    dadas.sort()
    vistas = {}
    for d, p, t in dadas:
        # orden: la dosis anterior de la misma cadena ya dada
        if p in ORDEN and ORDEN[p] > 1:
            prev = [q for q in ORDEN if CADENA.get(q) == CADENA[p] and ORDEN[q] == ORDEN[p] - 1]
            assert any(q in vistas for q in prev), (mid, p, 'sin la anterior')
        # días mínimos
        for q, dq in vistas.items():
            pass
        mismos = [x for x in dadas if x[1] in ({p} if p not in CADENA else {q for q in CADENA if CADENA[q] == CADENA[p]}) and x[0] < d]
        for x in mismos:
            minimo = 330 if p in (5, 10, 13) or (p in (6, 11) and x[1] in (6, 11)) else (14 if p in (1, 7) else 21)
            assert d - x[0] >= minimo, (mid, p, d, x[0], minimo)
        vistas[p] = d

# ---------- SQL ----------
def fecha_sql(base, d):
    if base == 'L':
        return f'@lunes + INTERVAL {d} DAY'
    # Los próximos días: si cae domingo, el lunes (futuro) o el sábado (pasado).
    return f'@hoy + INTERVAL ({d} + IF(DAYOFWEEK(@hoy + INTERVAL {d} DAY) = 1, {1 if d >= 0 else -1}, 0)) DAY'

def q(s):
    return 'NULL' if s is None else "'" + s.replace("'", "''") + "'"

L = []
L.append('''-- Producción 003 · seis meses de agenda, con sus consultas, facturas y calendario
-- (generado por base/semillas-produccion/generar.py: no editar a mano; cambiar el generador y volver
--  a correrlo).
--
--   Una clínica que cierra por todos lados:
--   - Cada vacuna o desparasitación dada sale de una consulta atendida (con su insumo, su factura y su
--     evento del calendario, con el ítem del plan de la especie), en el orden del plan y con los días
--     mínimos entre dosis (21 entre dosis de la serie, 330 entre refuerzos y antirrábicas).
--   - Los cachorros tienen su serie inicial; los adultos, la antirrábica anual, la tos de las perreras
--     y la desparasitación. Las mascotas de la demo, su historia completa desde cachorros.
--   - Castraciones con su control, una cirugía y una urgencia un sábado; cancelados y ausentes.
--   - Los lunes a la tarde casi no hay turnos (la franja que Reportes sugiere promocionar).
--   - Lo que viene: Rocco se vacuna en 3 días (la antirrábica de su calendario), Lola tiene consulta
--     en 5, y hay antirrábicas de otras mascotas en los próximos días (el motor las avisa).
--   Turnos y consultas 30001 a 30760 (la consulta y su factura C-0300.. tienen el id del turno; el
--   evento dado en una consulta, también). Eventos sin dar: 31001 en adelante.
--   Fechas: el pasado, respecto de @lunes (el lunes de esta semana: así cada turno cae en el día de la
--   semana que corresponde); los próximos días, respecto de @hoy (si cae domingo, el día hábil de al lado).
-- Correr de nuevo deja todo como estaba, con las fechas corridas a hoy. Borra todo lo de las mascotas
-- de los clientes (30001 a 30084), también lo que se hizo a mano en la demo.

SET @hoy = DATE(UTC_TIMESTAMP() - INTERVAL 3 HOUR);
SET @lunes = @hoy - INTERVAL WEEKDAY(@hoy) DAY;

-- 1. Lo anterior de estas mascotas, en orden (por las claves foráneas).
DELETE tm FROM turno_motivo tm JOIN turno t ON t.id = tm.turno_id WHERE t.mascota_id BETWEEN 30001 AND 30084;
DELETE tm FROM turno_motivo tm JOIN evento_sanitario e ON e.id = tm.evento_sanitario_id WHERE e.mascota_id BETWEEN 30001 AND 30084;
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id JOIN turno t ON t.id = c.turno_id WHERE t.mascota_id BETWEEN 30001 AND 30084;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id WHERE t.mascota_id BETWEEN 30001 AND 30084;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id JOIN turno t ON t.id = c.turno_id WHERE t.mascota_id BETWEEN 30001 AND 30084;
DELETE FROM evento_sanitario WHERE mascota_id BETWEEN 30001 AND 30084;
DELETE c FROM consulta c JOIN turno t ON t.id = c.turno_id WHERE t.mascota_id BETWEEN 30001 AND 30084;
DELETE FROM turno WHERE mascota_id BETWEEN 30001 AND 30084
  AND id NOT IN (SELECT turno_chequeo_id FROM (SELECT turno_chequeo_id FROM adopcion WHERE turno_chequeo_id IS NOT NULL) a);
-- Los turnos de la carga anterior que quedaron en este rango de ids (por ejemplo, de otra versión).
DELETE tm FROM turno_motivo tm WHERE tm.turno_id BETWEEN 30001 AND 30760;
DELETE f FROM factura_consulta f JOIN consulta c ON c.id = f.consulta_id WHERE c.turno_id BETWEEN 30001 AND 30760;
DELETE i FROM item_insumo_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 30001 AND 30760;
DELETE i FROM item_producto_consulta i JOIN consulta c ON c.id = i.consulta_id WHERE c.turno_id BETWEEN 30001 AND 30760;
UPDATE evento_sanitario e JOIN consulta c ON c.id = e.consulta_id SET e.consulta_id = NULL, e.fecha_aplicada = NULL WHERE c.turno_id BETWEEN 30001 AND 30760;
DELETE FROM consulta WHERE turno_id BETWEEN 30001 AND 30760;
DELETE FROM turno WHERE id BETWEEN 30001 AND 30760
  AND id NOT IN (SELECT turno_chequeo_id FROM (SELECT turno_chequeo_id FROM adopcion WHERE turno_chequeo_id IS NOT NULL) a);

-- 2. Los turnos. Un turno de los próximos días que cae en un horario ya ocupado por uno cargado a mano
--    (de otra mascota) no se carga: así nunca lo pisa.
DROP TEMPORARY TABLE IF EXISTS prod_turno;
CREATE TEMPORARY TABLE prod_turno (
  id INT UNSIGNED NOT NULL, mascota_id INT UNSIGNED NOT NULL, fecha DATE NOT NULL, hora TIME NOT NULL,
  motivo VARCHAR(20) NOT NULL, estado VARCHAR(20) NOT NULL, PRIMARY KEY (id)
);''')
filas = []
for t in turnos:
    hora = f"'{t['hora']}'" if t['base'] == 'L' else f"ADDTIME('{t['hora']}', IF(DAYOFWEEK(@hoy + INTERVAL {t['dia']} DAY) = 1, '00:05:00', '00:00:00'))"
    filas.append(f"  ({t['id']}, {t['mascota']}, {fecha_sql(t['base'], t['dia'])}, {hora}, '{t['motivos'][0][0]}', '{t['estado']}')")
for k in range(0, len(filas), 200):
    L.append('INSERT INTO prod_turno (id, mascota_id, fecha, hora, motivo, estado) VALUES\n' + ',\n'.join(filas[k:k + 200]) + ';')
L.append('''-- Hoy: los de la mañana atendidos y los de la tarde programados; si hoy es domingo, no hay.
DELETE FROM prod_turno WHERE fecha = @hoy AND DAYOFWEEK(@hoy) = 1;
INSERT INTO turno (id, mascota_id, veterinario_id, fecha, hora, motivo, estado, precio_consulta, descuento, promocion_franja_id)
SELECT p.id, p.mascota_id, @vet, p.fecha, p.hora, p.motivo, p.estado,
       IF(p.fecha < @hoy - INTERVAL 365 DAY, 9000.00, IF(p.fecha < @hoy - INTERVAL 90 DAY, 12000.00, 15000.00)), NULL, NULL
FROM prod_turno p
WHERE NOT EXISTS (SELECT 1 FROM turno o WHERE o.veterinario_id = @vet AND o.fecha = p.fecha AND o.hora = p.hora
                    AND o.estado <> 'CANCELADO' AND p.estado <> 'CANCELADO');''')

# Motivos de cada turno.
filas = []
for t in turnos:
    for motivo, plan in t['motivos']:
        filas.append((t['id'], motivo, plan))
L.append('''-- Los motivos de cada turno (migración 026). El evento del calendario de una vacunación: el que se
-- dio en su consulta (mismo id) o, si todavía no se atendió, el pendiente de su calendario.
DROP TEMPORARY TABLE IF EXISTS prod_motivo;
CREATE TEMPORARY TABLE prod_motivo (n INT NOT NULL AUTO_INCREMENT, turno_id INT UNSIGNED NOT NULL, motivo VARCHAR(20) NOT NULL,
  plan INT UNSIGNED NULL, PRIMARY KEY (n));''')
for k in range(0, len(filas), 300):
    L.append('INSERT INTO prod_motivo (turno_id, motivo, plan) VALUES\n' + ',\n'.join(
        f"  ({a}, '{b}', {c if c else 'NULL'})" for a, b, c in filas[k:k + 300]) + ';')

# Consultas de los atendidos.
filas = [t for t in turnos if t['estado'] == 'ATENDIDO']
L.append('''-- 3. Las consultas de los turnos atendidos (mismo id), con su diagnóstico.
DROP TEMPORARY TABLE IF EXISTS prod_consulta;
CREATE TEMPORARY TABLE prod_consulta (id INT UNSIGNED NOT NULL, diagnostico VARCHAR(500) NOT NULL, observaciones VARCHAR(500) NULL,
  PRIMARY KEY (id));''')
for k in range(0, len(filas), 200):
    L.append('INSERT INTO prod_consulta (id, diagnostico, observaciones) VALUES\n' + ',\n'.join(
        f"  ({t['id']}, {q(t['diag'])}, {q(t['obs'])})" for t in filas[k:k + 200]) + ';')
L.append('''INSERT INTO consulta (id, turno_id, diagnostico, observaciones, valor_base, estado, finalizada_en)
SELECT t.id, t.id, c.diagnostico, c.observaciones, t.precio_consulta, 'FINALIZADA',
       TIMESTAMP(t.fecha, t.hora) + INTERVAL (20 + t.id % 20) MINUTE
FROM prod_consulta c JOIN turno t ON t.id = c.id AND t.estado = 'ATENDIDO';''')

# Insumos y productos de cada consulta.
ins = [(t['id'], i, c) for t in filas for i, c in t['insumos']]
pro = [(t['id'], p, c) for t in filas for p, c in t['productos']]
L.append('''-- Lo que se usó: insumos (la vacuna de cada dosis y la jeringa; guantes, gasa, sutura...) y los
-- productos de la tienda que se llevó, al costo y al precio de hoy.
DROP TEMPORARY TABLE IF EXISTS prod_item;
CREATE TEMPORARY TABLE prod_item (n INT NOT NULL AUTO_INCREMENT, consulta_id INT UNSIGNED NOT NULL, tipo CHAR(1) NOT NULL,
  item INT UNSIGNED NOT NULL, cantidad INT NOT NULL, PRIMARY KEY (n));''')
todos = [(a, 'I', b, c) for a, b, c in ins] + [(a, 'P', b, c) for a, b, c in pro]
for k in range(0, len(todos), 400):
    L.append('INSERT INTO prod_item (consulta_id, tipo, item, cantidad) VALUES\n' + ',\n'.join(
        f"  ({a}, '{b}', {c}, {d})" for a, b, c, d in todos[k:k + 400]) + ';')
L.append('''INSERT INTO item_insumo_consulta (consulta_id, insumo_id, cantidad, costo_unitario)
SELECT p.consulta_id, i.id, p.cantidad, i.costo FROM prod_item p JOIN consulta c ON c.id = p.consulta_id JOIN insumo i ON i.id = p.item
WHERE p.tipo = 'I';
INSERT INTO item_producto_consulta (consulta_id, producto_id, cantidad, precio_unitario)
SELECT p.consulta_id, pr.id, p.cantidad, pr.precio FROM prod_item p JOIN consulta c ON c.id = p.consulta_id JOIN producto pr ON pr.id = p.item
WHERE p.tipo = 'P';

-- Las facturas (C-0300..., mismo id): pagadas si tienen más de una semana.
INSERT INTO factura_consulta
  (id, numero, consulta_id, subtotal_base, subtotal_insumos, subtotal_productos, total, huellitas_usadas, estado, fecha)
SELECT c.id, CONCAT('C-', LPAD(c.id, 6, '0')), c.id, c.valor_base,
       COALESCE(ii.subtotal, 0), COALESCE(ip.subtotal, 0),
       c.valor_base + COALESCE(ii.subtotal, 0) + COALESCE(ip.subtotal, 0), NULL,
       IF(c.finalizada_en < @hoy - INTERVAL 7 DAY, 'PAGADA', 'PENDIENTE_PAGO'), c.finalizada_en
FROM consulta c
LEFT JOIN (SELECT consulta_id, SUM(cantidad * costo_unitario) AS subtotal FROM item_insumo_consulta GROUP BY consulta_id) ii ON ii.consulta_id = c.id
LEFT JOIN (SELECT consulta_id, SUM(cantidad * precio_unitario) AS subtotal FROM item_producto_consulta GROUP BY consulta_id) ip ON ip.consulta_id = c.id
WHERE c.id BETWEEN 30001 AND 30760
ON DUPLICATE KEY UPDATE numero = VALUES(numero), consulta_id = VALUES(consulta_id), subtotal_base = VALUES(subtotal_base),
  subtotal_insumos = VALUES(subtotal_insumos), subtotal_productos = VALUES(subtotal_productos), total = VALUES(total),
  estado = VALUES(estado), fecha = VALUES(fecha);''')

# Eventos dados (uno por dosis; si una consulta da dos, el segundo con id 31500 + n).
dados = []
extra = [31501]
for t in filas:
    for k2, p in enumerate(t['dar']):
        eid = t['id'] if k2 == 0 else extra[0]
        if k2:
            extra[0] += 1
        dados.append((eid, t['id'], t['mascota'], p))
assert extra[0] < 32000
L.append('''-- 4. El calendario: cada dosis dada, con el ítem del plan, en la fecha de su consulta.
DROP TEMPORARY TABLE IF EXISTS prod_evento;
CREATE TEMPORARY TABLE prod_evento (id INT UNSIGNED NOT NULL, consulta_id INT UNSIGNED NULL, mascota_id INT UNSIGNED NOT NULL,
  plan INT UNSIGNED NOT NULL, fecha DATE NULL, turno_id INT UNSIGNED NULL, PRIMARY KEY (id));''')
L.append('INSERT INTO prod_evento (id, consulta_id, mascota_id, plan, fecha, turno_id) VALUES\n' + ',\n'.join(
    f'  ({a}, {b}, {c}, {d}, NULL, NULL)' for a, b, c, d in dados) + ';')
L.append('''INSERT INTO evento_sanitario (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
SELECT e.id, e.mascota_id, p.id, p.tipo, p.nombre, t.fecha, t.fecha, c.id
FROM prod_evento e JOIN consulta c ON c.id = e.consulta_id JOIN turno t ON t.id = c.turno_id JOIN plan_sanitario p ON p.id = e.plan;''')

# Pendientes.
L.append('-- Lo que falta dar (cargado en el calendario por la veterinaria): vencido, próximo o más adelante.')
filas_p = []
for k, (mid, plan, base, d, tid) in enumerate(pendientes):
    filas_p.append(f'  ({31001 + k}, NULL, {mid}, {plan}, {fecha_sql(base, d)}, {tid if tid else "NULL"})')
L.append('INSERT INTO prod_evento (id, consulta_id, mascota_id, plan, fecha, turno_id) VALUES\n' + ',\n'.join(filas_p) + ';')
L.append('''INSERT INTO evento_sanitario (id, mascota_id, plan_sanitario_id, tipo, nombre, fecha_programada, fecha_aplicada, consulta_id)
SELECT e.id, e.mascota_id, p.id, p.tipo, p.nombre, COALESCE(t.fecha, e.fecha), NULL, NULL
FROM prod_evento e JOIN plan_sanitario p ON p.id = e.plan LEFT JOIN turno t ON t.id = e.turno_id
WHERE e.consulta_id IS NULL;

-- Los motivos, con su evento: el dado en la consulta del turno o el pendiente que tiene ese turno.
INSERT INTO turno_motivo (turno_id, motivo, evento_sanitario_id)
SELECT m.turno_id, m.motivo,
       (SELECT e.id FROM prod_evento e JOIN evento_sanitario es ON es.id = e.id
        WHERE (e.consulta_id = m.turno_id OR e.turno_id = m.turno_id) AND e.plan = m.plan LIMIT 1)
FROM prod_motivo m JOIN turno t ON t.id = m.turno_id
ORDER BY m.n;

DROP TEMPORARY TABLE IF EXISTS prod_turno;
DROP TEMPORARY TABLE IF EXISTS prod_motivo;
DROP TEMPORARY TABLE IF EXISTS prod_consulta;
DROP TEMPORARY TABLE IF EXISTS prod_item;
DROP TEMPORARY TABLE IF EXISTS prod_evento;''')
io.open(G + '003_turnos_consultas.sql', 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')

# ---------- 008 ----------
S = ['''-- Producción 008 · 22 reseñas de clientes de fondo (ids 30001 a 30022), de los últimos 4 meses
-- (generado por base/semillas-produccion/generar.py). Cada autor fue atendido antes de escribirla, y
-- lo que cuenta pasó: la conjuntivitis de Nala, la castración de Bigote, la urgencia de Paloma un
-- sábado, la antirrábica, la adopción y la compra. La mitad tiene respuesta de la veterinaria de la
-- demo. Las más nuevas de 4 o 5 estrellas salen en la portada.
-- Correr de nuevo las deja así (también las respuestas).

SET @ahora = UTC_TIMESTAMP() - INTERVAL 3 HOUR;

INSERT INTO resena (id, autor_id, estrellas, texto, creada_en, respuesta, respondida_en, respondida_por)
VALUES''']
filas = []
for k, (n, est, dias, texto, resp) in enumerate(RESENAS, start=1):
    creada = f'@ahora - INTERVAL {dias} DAY - INTERVAL {(k * 5) % 9} HOUR'
    filas.append(f"  ({30000 + k}, {3000 + n}, {est}, {q(texto)}, {creada}, {q(resp)}, "
                 f"{'NULL' if resp is None else f'@ahora - INTERVAL {dias} DAY + INTERVAL 20 HOUR'}, {'NULL' if resp is None else '@vet'})")
S.append(',\n'.join(filas))
S.append('''ON DUPLICATE KEY UPDATE
  autor_id = VALUES(autor_id), estrellas = VALUES(estrellas), texto = VALUES(texto), creada_en = VALUES(creada_en),
  respuesta = VALUES(respuesta), respondida_en = VALUES(respondida_en), respondida_por = VALUES(respondida_por);''')
io.open(G + '008_resenas.sql', 'w', encoding='utf-8', newline='\n').write('\n'.join(S) + '\n')

print('turnos', len(turnos), 'atendidos', len([t for t in turnos if t['estado'] == 'ATENDIDO']), 'dosis', len(dados),
      'pendientes', len(pendientes), 'ultimo id', sig_turno[0] - 1)
