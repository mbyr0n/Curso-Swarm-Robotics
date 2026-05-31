-- Repulsion-based obstacle avoidance controller.
-- Each proximity reading is converted into a local repulsion vector; the robot
-- pivots away from the resulting force while keeping forward motion otherwise.

FORWARD_SPEED = 5
PIVOT_WHEEL_SPEED = 0
MAX_WHEEL_SPEED = 8
REPULSION_THRESHOLD = 0.08
MAX_REPULSION = 1
PROXIMITY_SENSOR_COUNT = 24

function clamp(value, min_value, max_value)
   return math.max(min_value, math.min(value, max_value))
end

function init()
end

function get_repulsion_force()
   local force_x = 0
   local force_y = 0

   -- Sum all proximity readings into one repulsion vector in robot coordinates.
   for i = 1, PROXIMITY_SENSOR_COUNT do
      local reading = robot.proximity[i]
      force_x = force_x + reading.value * math.cos(reading.angle)
      force_y = force_y + reading.value * math.sin(reading.angle)
   end

   return force_x, force_y
end

function step()
   local force_x, force_y = get_repulsion_force()
   local repulsion_length = math.sqrt(force_x^2 + force_y^2)
   local repulsion_angle = math.atan2(force_y, force_x)

   if repulsion_length > REPULSION_THRESHOLD then
      local front_factor = 0.3 + 0.7 * math.max(0, math.cos(repulsion_angle))
      local intensity = clamp((repulsion_length - REPULSION_THRESHOLD) /
                              (MAX_REPULSION - REPULSION_THRESHOLD), 0, 1)
      local turn_speed = (MAX_WHEEL_SPEED - FORWARD_SPEED) *
                         intensity * front_factor
      local pivot_speed = FORWARD_SPEED + turn_speed

      if repulsion_angle >= 0 then
         robot.wheels.set_velocity(clamp(pivot_speed, 0, MAX_WHEEL_SPEED),
                                   PIVOT_WHEEL_SPEED)
      else
         robot.wheels.set_velocity(PIVOT_WHEEL_SPEED,
                                   clamp(pivot_speed, 0, MAX_WHEEL_SPEED))
      end
   else
      robot.wheels.set_velocity(FORWARD_SPEED, FORWARD_SPEED)
   end
end

function reset()
   init()
end

function destroy()
   robot.wheels.set_velocity(0, 0)
end