local function assert_equal(actual, expected, message)
   if actual ~= expected then
      error(string.format("%s: expected %s, got %s",
                          message, tostring(expected), tostring(actual)), 2)
   end
end

local function make_robot(bernoulli_result)
   local wheel_commands = {}
   local robot_mock = {
      motor_ground = {
         { value = 1.0 },
         { value = 1.0 },
         { value = 1.0 },
         { value = 1.0 }
      },
      proximity = {},
      random = {
         uniform_int = function()
            return 1
         end,
         bernoulli = function()
            return bernoulli_result
         end
      },
      wheels = {
         set_velocity = function(left, right)
            wheel_commands[#wheel_commands + 1] = { left = left, right = right }
         end
      }
   }

   for i = 1, 24 do
      robot_mock.proximity[i] = { angle = 0, value = 0 }
   end

   return robot_mock, wheel_commands
end

robot, commands = make_robot(false)
dofile("aggregation/aggregation_one.lua")
init()
robot.proximity[1] = { angle = 0, value = 0.2 }
random_walk()
assert_equal(commands[1].left, -ROTATION_SPEED,
             "centered obstacle with false bernoulli turns left wheel backward")
assert_equal(commands[1].right, ROTATION_SPEED,
             "centered obstacle with false bernoulli turns right wheel forward")

robot, commands = make_robot(true)
init()
robot.motor_ground[1].value = 0.1
robot.motor_ground[2].value = 0.1
step()
assert_equal(commands[1].left, 0, "robot stops when two ground sensors see black")
assert_equal(commands[1].right, 0, "robot stops both wheels inside the aggregation spot")

print("aggregation_one tests passed")
