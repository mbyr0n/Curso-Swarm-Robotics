-- Two-spot aggregation controller using implicit communication.
-- Robots emit a local signal while evaluating a spot and stay only when enough
-- nearby peers are also aggregating.

FORWARD_SPEED = 15
LEAVING_SPEED = 3
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

AGGREGATION_SIGNAL = 1
NEARBY_RANGE = 60
MIN_WAIT_STEPS = 50
MAX_WAIT_STEPS = 100
REEVALUATE_MIN_STEPS = 80
REEVALUATE_MAX_STEPS = 140
LEAVE_PROBABILITY_0_NEIGHBORS = 0.80
LEAVE_PROBABILITY_1_NEIGHBOR = 0.45
LEAVE_PROBABILITY_2_NEIGHBORS = 0.20
LEAVE_PROBABILITY_3_OR_MORE_NEIGHBORS = 0.05

state = "searching"
rotation_steps = 0
rotation_direction = 1
wait_steps = 0
reevaluate_steps = 0

function init()
   state = "searching"
   rotation_steps = 0
   rotation_direction = 1
   wait_steps = 0
   reevaluate_steps = 0
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

function count_nearby_aggregating_robots()
   local count = 0

   for i = 1, #robot.range_and_bearing do
      local message = robot.range_and_bearing[i]
      if message.data[1] == AGGREGATION_SIGNAL and message.range < NEARBY_RANGE then
         count = count + 1
      end
   end

   return count
end

function get_leave_probability(nearby_count)
   if nearby_count <= 0 then
      return LEAVE_PROBABILITY_0_NEIGHBORS
   elseif nearby_count == 1 then
      return LEAVE_PROBABILITY_1_NEIGHBOR
   elseif nearby_count == 2 then
      return LEAVE_PROBABILITY_2_NEIGHBORS
   else
      return LEAVE_PROBABILITY_3_OR_MORE_NEIGHBORS
   end
end

function should_leave_spot(nearby_count)
   return robot.random.bernoulli(get_leave_probability(nearby_count))
end

function start_signal_emission()
   robot.range_and_bearing.set_data(1, AGGREGATION_SIGNAL)
   robot.leds.set_all_colors("red")
end

function stop_signal_emission()
   robot.range_and_bearing.set_data(1, 0)
   robot.leds.set_all_colors("black")
end

function random_walk(forward_speed)
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
      robot.wheels.set_velocity(forward_speed, forward_speed)
   end
end

function enter_waiting_state()
   state = "waiting"
   wait_steps = robot.random.uniform_int(MIN_WAIT_STEPS, MAX_WAIT_STEPS)
   start_signal_emission()
   robot.wheels.set_velocity(0, 0)
end

function reset_reevaluate_timer()
   reevaluate_steps = robot.random.uniform_int(REEVALUATE_MIN_STEPS,
                                               REEVALUATE_MAX_STEPS)
end

function enter_aggregated_state()
   state = "aggregated"
   reset_reevaluate_timer()
   start_signal_emission()
   robot.wheels.set_velocity(0, 0)
end

function enter_leaving_state()
   state = "leaving"
   rotation_steps = 0
   stop_signal_emission()
end

function step()
   if state == "searching" then
      stop_signal_emission()

      if is_in_spot() then
         enter_waiting_state()
      else
         random_walk(FORWARD_SPEED)
      end
   elseif state == "waiting" then
      start_signal_emission()
      robot.wheels.set_velocity(0, 0)
      wait_steps = wait_steps - 1

      if wait_steps <= 0 then
         if should_leave_spot(count_nearby_aggregating_robots()) then
            enter_leaving_state()
         else
            enter_aggregated_state()
         end
      end
   elseif state == "aggregated" then
      start_signal_emission()
      robot.wheels.set_velocity(0, 0)
      reevaluate_steps = reevaluate_steps - 1

      if reevaluate_steps <= 0 then
         if should_leave_spot(count_nearby_aggregating_robots()) then
            enter_leaving_state()
         else
            reset_reevaluate_timer()
         end
      end
   elseif state == "leaving" then
      stop_signal_emission()
      if not is_in_spot() then
         state = "searching"
      else
         random_walk(LEAVING_SPEED)
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