-- Individualistic aggregation controller for a single black region.
-- Robots random-walk until enough ground sensors detect the aggregation spot,
-- then stop and wait in place.

FORWARD_SPEED = 15
ROTATION_SPEED = 5
BLACK_THRESHOLD = 0.2
REQUIRED_BLACK_SENSORS = 2
OBSTACLE_THRESHOLD = 0.1
FRONT_ANGLE = math.pi / 4
CENTERED_OBSTACLE_EPSILON = 0.01
MIN_ROTATION_STEPS = 5
MAX_ROTATION_STEPS = 20
PROXIMITY_SENSOR_COUNT = 24
GROUND_SENSOR_COUNT = 4

rotation_steps = 0
rotation_direction = 1

function init()
   rotation_steps = 0
   rotation_direction = 1
end

function is_in_spot()
   local black_sensors = 0

   for i = 1, GROUND_SENSOR_COUNT do
      if robot.motor_ground[i].value < BLACK_THRESHOLD then
         black_sensors = black_sensors + 1
      end
   end

   return black_sensors >= REQUIRED_BLACK_SENSORS
end

function get_front_obstacle_force()
   local force_x = 0
   local force_y = 0

   for i = 1, PROXIMITY_SENSOR_COUNT do
      local reading = robot.proximity[i]
      if math.abs(reading.angle) <= FRONT_ANGLE and
         reading.value > OBSTACLE_THRESHOLD then
         force_x = force_x + reading.value * math.cos(reading.angle)
         force_y = force_y + reading.value * math.sin(reading.angle)
      end
   end

   return force_x, force_y
end

function choose_rotation_direction(force_y)
   if math.abs(force_y) <= CENTERED_OBSTACLE_EPSILON then
      if robot.random.bernoulli() then
         return 1
      else
         return -1
      end
   elseif force_y > 0 then
      return 1
   else
      return -1
   end
end

function random_walk()
   local force_x, force_y = get_front_obstacle_force()

   if rotation_steps == 0 and force_x > 0 then
      rotation_steps = robot.random.uniform_int(MIN_ROTATION_STEPS,
                                                MAX_ROTATION_STEPS)
      rotation_direction = choose_rotation_direction(force_y)
   end

   if rotation_steps > 0 then
      robot.wheels.set_velocity(rotation_direction * ROTATION_SPEED,
                                -rotation_direction * ROTATION_SPEED)
      rotation_steps = rotation_steps - 1
   else
      robot.wheels.set_velocity(FORWARD_SPEED, FORWARD_SPEED)
   end
end

function step()
   if is_in_spot() then
      robot.wheels.set_velocity(0, 0)
   else
      random_walk()
   end
end

function reset()
   init()
end

function destroy()
   robot.wheels.set_velocity(0, 0)
end