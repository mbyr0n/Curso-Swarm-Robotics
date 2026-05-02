-- Ballistic random walk parameters
FORWARD_SPEED = 5
ROTATION_SPEED = 5
OBSTACLE_THRESHOLD = 0.1
FRONT_ANGLE = math.pi / 4
MIN_ROTATION_STEPS = 5
MAX_ROTATION_STEPS = 20

rotation_steps = 0
rotation_direction = 1

function init()
   -- Each robot gets a slightly different random sequence.
   local seed = os.time()
   for i = 1, string.len(robot.id) do
      seed = seed + string.byte(robot.id, i)
   end
   math.randomseed(seed)
   rotation_steps = 0
   rotation_direction = 1
end

function step()
   local obstacle_in_front = false

   -- Only frontal proximity sensors trigger the ballistic turn.
   for i = 1, 24 do
      local reading = robot.proximity[i]
      if math.abs(reading.angle) <= FRONT_ANGLE and
         reading.value > OBSTACLE_THRESHOLD then
         obstacle_in_front = true
         break
      end
   end

   -- Start a new in-place rotation when a frontal obstacle is detected.
   if rotation_steps == 0 and obstacle_in_front then
      rotation_steps = math.random(MIN_ROTATION_STEPS, MAX_ROTATION_STEPS)
      if math.random() < 0.5 then
         rotation_direction = -1
      else
         rotation_direction = 1
      end
   end

   -- While rotating, ignore forward motion until the random turn finishes.
   if rotation_steps > 0 then
      robot.wheels.set_velocity(rotation_direction * ROTATION_SPEED,
                                -rotation_direction * ROTATION_SPEED)
      rotation_steps = rotation_steps - 1
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
