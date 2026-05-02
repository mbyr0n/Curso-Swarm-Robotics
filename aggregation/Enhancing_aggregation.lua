-- Enhanced two-spot aggregation controller with taxis.
-- Searching robots are attracted to signals emitted by robots already sampling
-- or aggregating in a spot, while obstacle avoidance remains the priority.

FORWARD_SPEED = 5
SAMPLE_SPEED = 3
ROTATION_SPEED = 5
TAXIS_SPEED = 8
BLACK_THRESHOLD = 0.2
REQUIRED_BLACK_SENSORS = 2
OBSTACLE_THRESHOLD = 0.1
FRONT_ANGLE = math.pi / 4
MIN_ROTATION_STEPS = 5
MAX_ROTATION_STEPS = 20
PROXIMITY_SENSOR_COUNT = 24
GROUND_SENSOR_COUNT = 4

AGGREGATION_SIGNAL = 1
NEARBY_RANGE = 60
CLUSTER_RANGE = 100
MIN_NEARBY_ROBOTS_TO_STAY = 3
MIN_SIGNALS_FOR_TAXIS = 1
MIN_WAIT_STEPS = 50
MAX_WAIT_STEPS = 100
MIN_SAMPLE_STEPS = 8
MAX_SAMPLE_STEPS = 18

state = "searching"
rotation_steps = 0
rotation_direction = 1
wait_steps = 0
sample_steps = 0

function init()
   state = "searching"
   rotation_steps = 0
   rotation_direction = 1
   wait_steps = 0
   sample_steps = 0
   stop_signal_emission()
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

function obstacle_in_front()
   for i = 1, PROXIMITY_SENSOR_COUNT do
      local reading = robot.proximity[i]
      if math.abs(reading.angle) <= FRONT_ANGLE and
         reading.value > OBSTACLE_THRESHOLD then
         return true
      end
   end

   return false
end

function count_nearby_aggregating_robots()
   local count = 0

   for i = 1, #robot.range_and_bearing do
      local message = robot.range_and_bearing[i]
      if message.data[1] == AGGREGATION_SIGNAL and message.range < CLUSTER_RANGE then
         count = count + 1
      end
   end

   return count
end

function get_attraction_vector()
   local attraction_x = 0
   local attraction_y = 0
   local signal_count = 0

   for i = 1, #robot.range_and_bearing do
      local message = robot.range_and_bearing[i]
      if message.data[1] == AGGREGATION_SIGNAL then
         local weight = 1 / math.max(message.range, 1)
         attraction_x = attraction_x + weight * math.cos(message.horizontal_bearing)
         attraction_y = attraction_y + weight * math.sin(message.horizontal_bearing)
         signal_count = signal_count + 1
      end
   end

   return attraction_x, attraction_y, signal_count
end

function start_signal_emission()
   robot.range_and_bearing.set_data(1, AGGREGATION_SIGNAL)
   robot.leds.set_all_colors("red")
end

function stop_signal_emission()
   robot.range_and_bearing.set_data(1, 0)
   robot.leds.set_all_colors("black")
end

function choose_rotation()
   rotation_steps = robot.random.uniform_int(MIN_ROTATION_STEPS,
                                             MAX_ROTATION_STEPS)
   if robot.random.bernoulli() == 0 then
      rotation_direction = -1
   else
      rotation_direction = 1
   end
end

function obstacle_avoidance(forward_speed)
   if rotation_steps == 0 and obstacle_in_front() then
      choose_rotation()
   end

   if rotation_steps > 0 then
      robot.wheels.set_velocity(rotation_direction * ROTATION_SPEED,
                                -rotation_direction * ROTATION_SPEED)
      rotation_steps = rotation_steps - 1
   else
      robot.wheels.set_velocity(forward_speed, forward_speed)
   end
end

function random_walk()
   obstacle_avoidance(FORWARD_SPEED)
end

function sample_spot_walk()
   obstacle_avoidance(SAMPLE_SPEED)
end

function taxis_walk()
   if rotation_steps > 0 or obstacle_in_front() then
      random_walk()
      return
   end

   local attraction_x, attraction_y, signal_count = get_attraction_vector()
   if signal_count < MIN_SIGNALS_FOR_TAXIS then
      random_walk()
      return
   end

   local attraction_angle = math.atan2(attraction_y, attraction_x)
   local wheel_speed = math.max(0.5, math.cos(attraction_angle)) * TAXIS_SPEED

   if attraction_angle > 0 then
      robot.wheels.set_velocity(0, wheel_speed)
   elseif attraction_angle < 0 then
      robot.wheels.set_velocity(wheel_speed, 0)
   else
      robot.wheels.set_velocity(FORWARD_SPEED, FORWARD_SPEED)
   end
end

function enter_waiting_state()
   state = "waiting"
   wait_steps = robot.random.uniform_int(MIN_WAIT_STEPS, MAX_WAIT_STEPS)
   start_signal_emission()
   robot.wheels.set_velocity(0, 0)
end

function step()
   if state == "searching" then
      stop_signal_emission()

      if is_in_spot() then
         enter_waiting_state()
      else
         taxis_walk()
      end
   elseif state == "waiting" then
      start_signal_emission()
      robot.wheels.set_velocity(0, 0)
      wait_steps = wait_steps - 1

      if count_nearby_aggregating_robots() >= MIN_NEARBY_ROBOTS_TO_STAY then
         state = "aggregated"
      elseif wait_steps <= 0 then
         state = "sampling_spot"
         sample_steps = robot.random.uniform_int(MIN_SAMPLE_STEPS,
                                                 MAX_SAMPLE_STEPS)
      end
   elseif state == "aggregated" then
      start_signal_emission()
      robot.wheels.set_velocity(0, 0)
   elseif state == "sampling_spot" then
      start_signal_emission()
      sample_spot_walk()
      sample_steps = sample_steps - 1

      if not is_in_spot() then
         state = "searching"
      elseif sample_steps <= 0 then
         enter_waiting_state()
      end
   end
end

function reset()
   init()
end

function destroy()
   stop_signal_emission()
   robot.wheels.set_velocity(0, 0)
end
