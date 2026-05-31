-- Circular pattern formation controller.
-- Robots combine Lennard-Jones inter-robot forces with attraction toward the
-- red LED perceived by the omnidirectional camera.

TARGET_DIST = 80
EPSILON = 50
WHEEL_SPEED = 5
MAX_FORCE = 20
LED_ATTRACTION_GAIN = 0.04
MAX_LED_FORCE = 12

function step()
    robot.range_and_bearing.set_data(1, 1)

    local force_x, force_y = ComputeLennardJonesForce()
    local led_x, led_y = ComputeLedAttractionForce()

    force_x = force_x + led_x
    force_y = force_y + led_y

    if force_x == 0 and force_y == 0 then
        robot.wheels.set_velocity(0, 0)
        return
    end

    local mov_dir = math.atan2(force_y, force_x)
    local speeds = ComputeSpeedFromAngle(mov_dir)

    robot.wheels.set_velocity(speeds[1], speeds[2])
end

function ComputeLennardJonesForce()
    local force_x = 0
    local force_y = 0

    for i = 1, #robot.range_and_bearing do
        local message = robot.range_and_bearing[i]
        local ln_value = ComputeLennardJones(message.range)

        force_x = force_x + ln_value * math.cos(message.horizontal_bearing)
        force_y = force_y + ln_value * math.sin(message.horizontal_bearing)
    end

    return force_x, force_y
end

function ComputeLedAttractionForce()
    local force_x = 0
    local force_y = 0

    for i = 1, #robot.colored_blob_omnidirectional_camera do
        local blob = robot.colored_blob_omnidirectional_camera[i]
        if blob.color.red > 200 and blob.color.green < 100 and blob.color.blue < 100 then
            local led_force = math.min(blob.distance * LED_ATTRACTION_GAIN,
                                       MAX_LED_FORCE)
            force_x = force_x + led_force * math.cos(blob.angle)
            force_y = force_y + led_force * math.sin(blob.angle)
        end
    end

    return force_x, force_y
end

function ComputeLennardJones(distance)
    if distance <= 0 then
        return -MAX_FORCE
    end

    local ratio = TARGET_DIST / distance
    local force = -EPSILON / distance * (ratio^4 - ratio^2)

    return math.max(-MAX_FORCE, math.min(force, MAX_FORCE))
end

function ComputeSpeedFromAngle(angle)
    dotProduct = 0.0;
    KProp = 20;
    wheelsDistance = 0.14;

    if angle > math.pi/2 or angle < -math.pi/2 then
        dotProduct = 0.0;
    else
        forwardVector = {math.cos(0), math.sin(0)}
        targetVector = {math.cos(angle), math.sin(angle)}
        dotProduct = forwardVector[1]*targetVector[1]+forwardVector[2]*targetVector[2]
    end

    angularVelocity = KProp * angle;
    speeds = {dotProduct * WHEEL_SPEED - angularVelocity * wheelsDistance,
              dotProduct * WHEEL_SPEED + angularVelocity * wheelsDistance}

    return speeds
end

function init()
    robot.range_and_bearing.set_data(1, 1)
    robot.colored_blob_omnidirectional_camera.enable()
end

function reset()
    init()
end

function destroy()
    robot.wheels.set_velocity(0, 0)
    robot.range_and_bearing.set_data(1, 0)
    robot.colored_blob_omnidirectional_camera.disable()
end