local function assert_equal(actual, expected, message)
   if actual ~= expected then
      error(string.format("%s: expected %s, got %s",
                          message, tostring(expected), tostring(actual)), 2)
   end
end

local function make_robot(bernoulli_result, messages)
   local wheel_commands = {}
   local led_colors = {}
   local rab_data = {}
   local bernoulli_probabilities = {}
   local robot_mock = {
      id = "fb1",
      motor_ground = {
         { value = 1.0 },
         { value = 1.0 },
         { value = 1.0 },
         { value = 1.0 }
      },
      proximity = {},
      range_and_bearing = messages or {},
      random = {
         uniform_int = function()
            return 1
         end,
         bernoulli = function(probability)
            bernoulli_probabilities[#bernoulli_probabilities + 1] = probability
            return bernoulli_result
         end
      },
      leds = {
         set_all_colors = function(color)
            led_colors[#led_colors + 1] = color
         end
      },
      wheels = {
         set_velocity = function(left, right)
            wheel_commands[#wheel_commands + 1] = { left = left, right = right }
         end
      }
   }
   robot_mock.range_and_bearing.set_data = function(index, value)
      rab_data[index] = value
   end

   for i = 1, 24 do
      robot_mock.proximity[i] = { angle = 0, value = 0 }
   end

   return robot_mock, wheel_commands, led_colors, rab_data, bernoulli_probabilities
end

robot, commands, led_colors, rab_data = make_robot(false)
dofile("aggregation/aggregation_two.lua")
init()
robot.proximity[1] = { angle = 0, value = 0.2 }
random_walk(FORWARD_SPEED)
assert_equal(commands[#commands].left, -ROTATION_SPEED,
             "centered obstacle with false bernoulli turns left wheel backward")
assert_equal(commands[#commands].right, ROTATION_SPEED,
             "centered obstacle with false bernoulli turns right wheel forward")

robot, commands, led_colors, rab_data = make_robot(true)
init()
robot.motor_ground[1].value = 0.1
robot.motor_ground[2].value = 0.1
step()
assert_equal(state, "waiting", "spot detection enters waiting state")
step()
assert_equal(state, "leaving", "few neighbors send robot to leaving state")
assert_equal(rab_data[1], 0, "leaving state clears range-and-bearing signal")
assert_equal(led_colors[#led_colors], "black", "leaving state clears LED signal")

robot, commands, led_colors, rab_data, bernoulli_probabilities = make_robot(false, {
   { data = { AGGREGATION_SIGNAL }, range = 30 }
})
init()
robot.motor_ground[1].value = 0.1
robot.motor_ground[2].value = 0.1
step()
step()
assert_equal(state, "aggregated", "one neighbor can be enough when the probabilistic decision says stay")
assert_equal(bernoulli_probabilities[#bernoulli_probabilities], 0.45,
             "one neighbor uses the configured leave probability")

robot, commands, led_colors, rab_data = make_robot(false, {
   { data = { AGGREGATION_SIGNAL }, range = 30 },
   { data = { AGGREGATION_SIGNAL }, range = 40 },
   { data = { AGGREGATION_SIGNAL }, range = 50 }
})
init()
robot.motor_ground[1].value = 0.1
robot.motor_ground[2].value = 0.1
step()
step()
assert_equal(state, "aggregated", "three neighbors keep the robot aggregated")
assert_equal(rab_data[1], AGGREGATION_SIGNAL, "aggregated state keeps range-and-bearing signal on")

robot, commands, led_colors, rab_data = make_robot(true)
init()
state = "aggregated"
reevaluate_steps = 1
step()
assert_equal(state, "leaving", "aggregated robot can leave after reevaluating an empty cluster")

print("aggregation_two tests passed")
