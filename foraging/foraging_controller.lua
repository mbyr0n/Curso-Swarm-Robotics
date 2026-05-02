-- Foraging controller with forbidden-area avoidance.
-- Robots search for food, carry items toward the nest, mark forbidden areas as
-- danger beacons, and use local signals to improve swarm-level navigation.

-- ============================================================
-- CONSTANTES
-- ============================================================
MAX_SPEED             = 15
TURN_SPEED            = 8

-- Señales range_and_bearing
CARRY_SIGNAL          = 1
DANGER_SIGNAL         = 2
NEST_SIGNAL           = 3

-- Zona prohibida
DANGER_RANGE          = 180
DANGER_REPULSION_GAIN = 3.5   -- era 2.5, subimos para reacción más temprana

-- Nido
NEST_RANGE            = 400
NEST_ATTRACTION_GAIN  = 16

-- Navegación al nido
LIGHT_HOME_GAIN       = 0.15
LIGHT_HOME_ACTIVE_STEPS = 80
HOME_WANDER_GAIN      = 5
NEST_EXPLORER_LIGHT_GAIN = 0.05
NEST_EXPLORER_WANDER_GAIN = 8

-- Formación (Lennard-Jones entre portadores)
CARRY_PATTERN_DELAY   = 50
CARRY_PATTERN_RANGE   = 150
CARRY_TARGET_DIST     = 70
CARRY_PATTERN_EPSILON = 45
CARRY_PATTERN_GAIN    = 1.2
CARRY_PATTERN_MAX_FORCE = 8

-- Sensores
OBSTACLE_THRESHOLD    = 0.1
FRONT_ANGLE           = math.pi / 4
PROXIMITY_SENSOR_COUNT = 24
GROUND_SENSOR_COUNT   = 4
BASE_GROUND_SENSOR_COUNT = 8
LIGHT_SENSOR_COUNT    = 24

-- Umbrales de suelo
FOOD_THRESHOLD        = 0.12
FOOD_GROUND_SENSOR_COUNT = 1
FORBIDDEN_MIN         = 0.12
FORBIDDEN_MAX         = 0.35
NEST_THRESHOLD        = 0.85
NEST_GROUND_SENSOR_COUNT = 2

-- Timers
ESCAPE_STEPS          = 35    -- era 15, necesitamos más tiempo para salir bien
NEST_BEACON_STEPS     = 160
PERMANENT_NEST_BEACON = true
HOME_WANDER_MIN_STEPS = 20
HOME_WANDER_MAX_STEPS = 45
MIN_ROTATION_STEPS    = 6
MAX_ROTATION_STEPS    = 18

-- Evasión proactiva del área prohibida (sensor de proximidad al piso)
FORBIDDEN_APPROACH_STEPS = 20  -- NUEVO: tiempo extra de huida si detecta zona gris cerca
PROXIMITY_FORBIDDEN_GAIN = 5.0 -- NUEVO: ganancia del campo repulsivo del área

-- ============================================================
-- ESTADO GLOBAL DEL ROBOT
-- ============================================================
state              = "search_food"
prev_state         = "search_food"  -- NUEVO: recuerda el estado antes de escapar
escape_steps       = 0
nest_beacon_steps  = 0
carry_steps        = 0
home_wander_steps  = 0
home_wander_angle  = 0
rotation_steps     = 0
rotation_direction = 1
has_item           = false          -- NUEVO: rastreo explícito del ítem

-- ============================================================
-- INIT / RESET / DESTROY
-- ============================================================
function init()
    state              = "search_food"
    prev_state         = "search_food"
    escape_steps       = 0
    nest_beacon_steps  = 0
    carry_steps        = 0
    home_wander_steps  = 0
    home_wander_angle  = 0
    rotation_steps     = 0
    rotation_direction = 1
    has_item           = false
    robot.range_and_bearing.set_data(1, 0)
    robot.leds.set_all_colors("black")
end

function reset() init() end

function destroy()
    robot.wheels.set_velocity(0, 0)
    robot.range_and_bearing.set_data(1, 0)
    robot.leds.set_all_colors("black")
end

-- ============================================================
-- UTILIDADES DE ÁNGULO
-- ============================================================
function normalize_angle(angle)
    while angle >  math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- ============================================================
-- LECTURA DE SUELO
-- ============================================================
function ground_min_value()
    local v = 1
    for i = 1, GROUND_SENSOR_COUNT do
        v = math.min(v, robot.motor_ground[i].value)
    end
    return v
end

function ground_max_value()
    local v = 0
    for i = 1, GROUND_SENSOR_COUNT do
        v = math.max(v, robot.motor_ground[i].value)
    end
    return v
end

function count_base_ground_below(threshold)
    local count = 0
    for i = 1, BASE_GROUND_SENSOR_COUNT do
        if robot.base_ground[i].value < threshold then
            count = count + 1
        end
    end
    return count
end

function count_base_ground_above(threshold)
    local count = 0
    for i = 1, BASE_GROUND_SENSOR_COUNT do
        if robot.base_ground[i].value > threshold then
            count = count + 1
        end
    end
    return count
end

function count_motor_ground_below(threshold)
    local count = 0
    for i = 1, GROUND_SENSOR_COUNT do
        if robot.motor_ground[i].value < threshold then
            count = count + 1
        end
    end
    return count
end

function count_motor_ground_above(threshold)
    local count = 0
    for i = 1, GROUND_SENSOR_COUNT do
        if robot.motor_ground[i].value > threshold then
            count = count + 1
        end
    end
    return count
end

function is_on_food()
    return count_motor_ground_below(FOOD_THRESHOLD) >= FOOD_GROUND_SENSOR_COUNT
end

function is_on_nest()
    return count_motor_ground_above(NEST_THRESHOLD) >= NEST_GROUND_SENSOR_COUNT
end

function is_on_forbidden_area()
    local mn = ground_min_value()
    return mn >= FORBIDDEN_MIN and mn < FORBIDDEN_MAX
end

-- ============================================================
-- NUEVO: detección de zona prohibida ANTES de pisarla
-- Usa los sensores de suelo periféricos (no solo min)
-- ============================================================
function is_approaching_forbidden()
    local count = 0
    for i = 1, GROUND_SENSOR_COUNT do
        local v = robot.motor_ground[i].value
        if v >= FORBIDDEN_MIN and v < FORBIDDEN_MAX then
            count = count + 1
        end
    end
    -- Si al menos 1 sensor toca zona gris y aún no estamos dentro
    return count >= 1
end

-- ============================================================
-- OBSTÁCULOS
-- ============================================================
function get_obstacle_direction()
    local left, right = 0, 0
    for i = 1, PROXIMITY_SENSOR_COUNT do
        local r = robot.proximity[i]
        if math.abs(r.angle) <= FRONT_ANGLE and r.value > OBSTACLE_THRESHOLD then
            if r.angle >= 0 then left  = left  + r.value
            else                  right = right + r.value
            end
        end
    end
    if left == 0 and right == 0 then return 0
    elseif left >= right          then return -1
    else                               return  1
    end
end

-- ============================================================
-- VECTORES DE FUERZA
-- ============================================================
function get_light_vector()
    local x, y = 0, 0
    for i = 1, LIGHT_SENSOR_COUNT do
        local r = robot.light[i]
        x = x + r.value * math.cos(r.angle)
        y = y + r.value * math.sin(r.angle)
    end
    return x, y
end

-- MEJORADO: repulsión del área prohibida más fuerte y con mayor rango
function get_danger_repulsion_vector()
    local x, y = 0, 0
    for i = 1, #robot.range_and_bearing do
        local msg = robot.range_and_bearing[i]
        if msg.data[1] == DANGER_SIGNAL and msg.range < DANGER_RANGE then
            local weight = DANGER_REPULSION_GAIN * (DANGER_RANGE - msg.range) / DANGER_RANGE
            x = x - weight * math.cos(msg.horizontal_bearing)
            y = y - weight * math.sin(msg.horizontal_bearing)
        end
    end
    return x, y
end

function get_nest_attraction_vector()
    local x, y = 0, 0
    local count = 0
    for i = 1, #robot.range_and_bearing do
        local msg = robot.range_and_bearing[i]
        if msg.data[1] == NEST_SIGNAL and msg.range < NEST_RANGE then
            local weight = NEST_ATTRACTION_GAIN * (NEST_RANGE - msg.range) / NEST_RANGE
            x = x + weight * math.cos(msg.horizontal_bearing)
            y = y + weight * math.sin(msg.horizontal_bearing)
            count = count + 1
        end
    end
    return x, y, count
end

-- NUEVO: campo repulsivo basado en lectura de suelo gris
-- Calcula la dirección promedio ponderada hacia los sensores que ven zona gris
-- y devuelve un vector de HUIDA (opuesto)
function get_ground_forbidden_repulsion()
    local fx, fy = 0, 0
    -- Los sensores de suelo están en posiciones fijas alrededor del robot
    -- ARGoS los numera 1..4: frontal-izq, frontal-der, trasero-izq, trasero-der
    -- Ángulos aproximados (ajusta si tu foot-bot los tiene diferente):
    local sensor_angles = {
        math.pi / 4,        -- frontal izquierdo
        -math.pi / 4,       -- frontal derecho
        3 * math.pi / 4,    -- trasero izquierdo
        -3 * math.pi / 4    -- trasero derecho
    }
    for i = 1, GROUND_SENSOR_COUNT do
        local v = robot.motor_ground[i].value
        if v >= FORBIDDEN_MIN and v < FORBIDDEN_MAX then
            -- Peso proporcional a cuán "oscuro" está el sensor (más oscuro = más cerca del centro)
            local weight = PROXIMITY_FORBIDDEN_GAIN * (1 - (v - FORBIDDEN_MIN) / (FORBIDDEN_MAX - FORBIDDEN_MIN))
            -- Repulsión: opuesto a la dirección del sensor
            fx = fx - weight * math.cos(sensor_angles[i])
            fy = fy - weight * math.sin(sensor_angles[i])
        end
    end
    return fx, fy
end

function compute_carry_lennard_jones(distance)
    if distance <= 0 then return -CARRY_PATTERN_MAX_FORCE end
    local ratio = CARRY_TARGET_DIST / distance
    local force = -CARRY_PATTERN_EPSILON / distance * (ratio^4 - ratio^2)
    return math.max(-CARRY_PATTERN_MAX_FORCE, math.min(force, CARRY_PATTERN_MAX_FORCE))
end

function get_carry_pattern_vector()
    local x, y = 0, 0
    for i = 1, #robot.range_and_bearing do
        local msg = robot.range_and_bearing[i]
        if msg.data[1] == CARRY_SIGNAL and msg.range < CARRY_PATTERN_RANGE then
            local force = compute_carry_lennard_jones(msg.range) * CARRY_PATTERN_GAIN
            x = x + force * math.cos(msg.horizontal_bearing)
            y = y + force * math.sin(msg.horizontal_bearing)
        end
    end
    return x, y
end

-- ============================================================
-- MOVIMIENTO BASE
-- ============================================================
function start_random_rotation()
    rotation_steps = robot.random.uniform_int(MIN_ROTATION_STEPS, MAX_ROTATION_STEPS)
    rotation_direction = robot.random.bernoulli() == 0 and -1 or 1
end

function move_towards_angle(angle)
    if rotation_steps > 0 then
        robot.wheels.set_velocity(
            rotation_direction * TURN_SPEED,
           -rotation_direction * TURN_SPEED)
        rotation_steps = rotation_steps - 1
        return
    end
    local obs = get_obstacle_direction()
    if obs ~= 0 then
        start_random_rotation()
        robot.wheels.set_velocity(-obs * TURN_SPEED, obs * TURN_SPEED)
        return
    end
    local forward = math.max(0, math.cos(angle)) * MAX_SPEED
    local turn    = angle * 6
    robot.wheels.set_velocity(forward - turn, forward + turn)
end

-- ============================================================
-- COMPORTAMIENTOS DE NAVEGACIÓN
-- ============================================================
function follow_light()
    local x, y       = get_light_vector()
    local dx, dy     = get_danger_repulsion_vector()
    local gx, gy     = get_ground_forbidden_repulsion()  -- NUEVO
    x = x + dx + gx
    y = y + dy + gy
    if x == 0 and y == 0 then move_towards_angle(0); return end
    move_towards_angle(math.atan2(y, x))
end

function move_away_from_light()
    local x, y   = get_light_vector()
    local dx, dy = get_danger_repulsion_vector()
    local nx, ny, nest_count = get_nest_attraction_vector()
    local gx, gy = get_ground_forbidden_repulsion()  -- NUEVO
    local px, py = 0, 0

    if home_wander_steps <= 0 then
        home_wander_steps = robot.random.uniform_int(HOME_WANDER_MIN_STEPS, HOME_WANDER_MAX_STEPS)
        home_wander_angle = robot.random.uniform(-math.pi, math.pi)
    end
    home_wander_steps = home_wander_steps - 1

    local wander_gain = HOME_WANDER_GAIN
    local light_gain = LIGHT_HOME_GAIN
    if carry_steps > LIGHT_HOME_ACTIVE_STEPS then
        light_gain = 0
    end

    if nest_count > 0 then
        wander_gain = 0.5
        light_gain = 0.02
    end

    local wx = wander_gain * math.cos(home_wander_angle)
    local wy = wander_gain * math.sin(home_wander_angle)

    if carry_steps >= CARRY_PATTERN_DELAY then
        px, py = get_carry_pattern_vector()
    end

    -- MEJORADO: pesos rebalanceados para que la evasión tenga prioridad
    x = -light_gain * x + 1.5*dx + nx + wx + px + 2.0*gx
    y = -light_gain * y + 1.5*dy + ny + wy + py + 2.0*gy

    if x == 0 and y == 0 then move_towards_angle(0); return end
    move_towards_angle(math.atan2(y, x))
end

function explore_nest()
    local lx, ly = get_light_vector()
    local dx, dy = get_danger_repulsion_vector()
    local gx, gy = get_ground_forbidden_repulsion()

    if home_wander_steps <= 0 then
        home_wander_steps = robot.random.uniform_int(HOME_WANDER_MIN_STEPS,
                                                     HOME_WANDER_MAX_STEPS)
        home_wander_angle = robot.random.uniform(-math.pi, math.pi)
    end
    home_wander_steps = home_wander_steps - 1

    local wx = NEST_EXPLORER_WANDER_GAIN * math.cos(home_wander_angle)
    local wy = NEST_EXPLORER_WANDER_GAIN * math.sin(home_wander_angle)

    local x = wx - NEST_EXPLORER_LIGHT_GAIN * lx + 1.5 * dx + 2.0 * gx
    local y = wy - NEST_EXPLORER_LIGHT_GAIN * ly + 1.5 * dy + 2.0 * gy

    if x == 0 and y == 0 then move_towards_angle(0); return end
    move_towards_angle(math.atan2(y, x))
end

-- ============================================================
-- BEACONS
-- ============================================================
-- Robots that reach the forbidden area become static danger markers.
function danger_beacon_behavior()
    robot.leds.set_all_colors("red")
    robot.range_and_bearing.set_data(1, DANGER_SIGNAL)
    robot.wheels.set_velocity(0, 0)
end

function nest_beacon_behavior()
    robot.leds.set_all_colors("white")
    robot.range_and_bearing.set_data(1, NEST_SIGNAL)
    robot.wheels.set_velocity(0, 0)
    if PERMANENT_NEST_BEACON then
        return
    end

    nest_beacon_steps = nest_beacon_steps - 1
    if nest_beacon_steps <= 0 then
        state = "search_food"
        has_item = false
    end
end

-- NUEVO: estado de escape activo — el robot huye del área prohibida
function escape_forbidden_behavior()
    robot.leds.set_all_colors("orange")
    robot.range_and_bearing.set_data(1, DANGER_SIGNAL)

    escape_steps = escape_steps - 1

    local gx, gy = get_ground_forbidden_repulsion()
    local dx, dy = get_danger_repulsion_vector()
    local lx, ly = get_light_vector()

    -- Combina huida del área + alejarse de la luz (va al nido)
    local fx = gx + dx - 0.2 * lx
    local fy = gy + dy - 0.2 * ly

    if fx == 0 and fy == 0 then
        -- Si no hay señal clara, retrocede
        robot.wheels.set_velocity(-MAX_SPEED, -MAX_SPEED)
    else
        move_towards_angle(math.atan2(fy, fx))
    end

    if escape_steps <= 0 then
        state = prev_state
    end
end

-- ============================================================
-- STEP PRINCIPAL
-- ============================================================
function step()
    -- A robot on forbidden ground becomes a local warning sign for the swarm.
    if is_on_forbidden_area() then
        if state ~= "danger_beacon" and state ~= "escape_forbidden" then
            state      = "danger_beacon"
            prev_state = "search_food"
            has_item   = false
        end
    end

    -- ---- SEARCH FOOD ----
    if state == "search_food" then
        robot.leds.set_all_colors("green")
        robot.range_and_bearing.set_data(1, 0)
        has_item = false

        if is_on_nest() then
            state             = "nest_beacon"
            nest_beacon_steps = NEST_BEACON_STEPS
        elseif is_on_food() then
            state             = "go_nest"
            carry_steps       = 0
            home_wander_steps = 0
            has_item          = true
        else
            follow_light()
        end

    -- ---- GO NEST ----
    elseif state == "go_nest" then
        robot.leds.set_all_colors("blue")
        robot.range_and_bearing.set_data(1, CARRY_SIGNAL)
        carry_steps = carry_steps + 1
        has_item    = true

        if is_on_nest() then
            state             = "nest_beacon"
            nest_beacon_steps = NEST_BEACON_STEPS
            has_item          = false
        else
            move_away_from_light()
        end

    -- ---- DANGER BEACON (con ítem, emite señal y luego escapa) ----
    elseif state == "danger_beacon" then
        danger_beacon_behavior()

    -- ---- ESCAPE FORBIDDEN (huida activa) ----
    elseif state == "escape_forbidden" then
        escape_forbidden_behavior()

    -- ---- NEST BEACON ----
    elseif state == "nest_beacon" then
        nest_beacon_behavior()
    end
end
