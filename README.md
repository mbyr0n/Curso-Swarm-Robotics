# Swarm Robotics Practical Exercises

This repository contains ARGoS/Lua implementations for the swarm robotics practical sessions from the Robotics 101 course. The controllers implement local, decentralized behaviors for obstacle avoidance, aggregation, pattern formation, flocking, and a foraging project with forbidden areas.

All behaviors are designed for homogeneous foot-bot swarms. Each robot executes the same controller and makes decisions from local sensor readings only.

## Requirements

- ARGoS 3 with Lua support
- Foot-bot plugins and simulator libraries
- A working shell environment with `argos3`, `cmake`, and `make`

The repository already includes an ARGoS installation under `argos3-dist/`.

## Running Experiments

Most exercises can be launched directly with `argos3 -c <experiment.argos>` from their corresponding directory.

For the foraging project, the loop function plugin must be compiled first:

```bash
cd ~/swarm_robotics/foraging
mkdir -p build
cd build
cmake ../src
make
export ARGOS_PLUGIN_PATH=$ARGOS_PLUGIN_PATH:$HOME/swarm_robotics/foraging/build/
```

## Obstacle Avoidance and Random Walk

Directory:

```text
obstacle_avoidance/
```

### Ballistic Motion

Controller:

```text
obstacle_avoidance/ballistic_motion.lua
```

Experiments:

```text
obstacle_avoidance_scatter.argos
obstacle_avoidance_empty.argos
```

This controller implements a ballistic random walk strategy:

- The robot moves forward while no obstacle is detected.
- Frontal proximity sensors detect obstacles within a configurable angular range.
- When an obstacle is detected, the robot performs an in-place random rotation.
- After the rotation finishes, the robot resumes forward motion.

Run:

```bash
cd ~/swarm_robotics/obstacle_avoidance
argos3 -c obstacle_avoidance_scatter.argos
```

### Repulsion-Based Obstacle Avoidance

Controller:

```text
obstacle_avoidance/Obstacle_avoidance.lua
```

Experiment:

```text
obstacle_avoidance_empty.argos
```

This controller computes a repulsion vector from all proximity sensor readings:

- Each proximity reading contributes a vector in robot-local coordinates.
- The vectors are summed into a single repulsion force.
- If the force is strong enough, the robot pivots away from the obstacle.
- Otherwise, it moves forward.

The behavior is smoother than pure ballistic motion and works better for robot-to-robot avoidance in an open arena.

Run:

```bash
cd ~/swarm_robotics/obstacle_avoidance
argos3 -c obstacle_avoidance_empty.argos
```

## Aggregation

Directory:

```text
aggregation/
```

### Exercise 1: Aggregation in One Region of Interest

Controller:

```text
aggregation/aggregation.lua
```

Experiment:

```text
aggregation_one_spot.argos
```

This controller implements individualistic aggregation:

- Robots randomly walk through the arena.
- Ground sensors detect the black aggregation region.
- A robot stops when enough ground sensors detect black.
- Obstacle avoidance is handled with ballistic motion.

Run:

```bash
cd ~/swarm_robotics/aggregation
argos3 -c aggregation_one_spot.argos
```

### Exercise 2: Aggregation as Implicit Decision Making

Controller:

```text
aggregation/aggregation_one.lua
```

Experiment:

```text
aggregation_two_spot.argos
```

This controller extends one-spot aggregation to two possible regions:

- Robots search for black spots.
- When a robot reaches a spot, it emits an aggregation signal through range-and-bearing.
- It waits and counts nearby robots emitting the same signal.
- If enough peers are nearby, it remains aggregated.
- If not, it samples the spot by moving a few steps and reevaluating.
- If it exits the spot, it resumes searching.

This implements implicit communication: robots influence each other by their presence and emitted local signals.

Run:

```bash
cd ~/swarm_robotics/aggregation
argos3 -c aggregation_two_spot.argos
```

### Exercise 3: Enhanced Aggregation with Taxis

Controller:

```text
aggregation/Enhancing_aggregation.lua
```

Experiment:

```text
aggregation_two_spot.argos
```

This controller adds taxis behavior to speed up aggregation:

- Robots already aggregating emit a signal.
- Searching robots build an attraction vector from received signals.
- If no obstacle is in front, they move toward the group.
- Obstacle avoidance has priority over attraction.

This creates positive feedback: larger clusters attract more robots, helping the swarm converge faster to one aggregation region.

Run:

```bash
cd ~/swarm_robotics/aggregation
argos3 -c aggregation_two_spot.argos
```

## Pattern Formation

Directory:

```text
pattern_formation/
```

### Exercise 1: Hexagonal Pattern Formation

Controller:

```text
pattern_formation/Hexagonal_pattern_formation.lua
```

Experiment:

```text
pattern_formation.argos
```

This controller uses artificial potential fields based on a Lennard-Jones-like force:

- Nearby robots repel each other.
- Distant robots attract each other.
- Robots stabilize around a target inter-robot distance.
- The local equilibrium produces a hexagonal or triangular lattice structure.

The force from each neighbor is computed from its range and bearing, converted into a vector, and summed into a resulting movement direction.

Run:

```bash
cd ~/swarm_robotics/pattern_formation
argos3 -c pattern_formation.argos
```

### Exercise 2: Circular Pattern Formation

Controller:

```text
pattern_formation/Circular_pattern_formation.lua
```

Experiment:

```text
pattern_formation.argos
```

This controller combines two forces:

- Lennard-Jones interaction between robots.
- Attraction toward a red LED detected by the omnidirectional camera.

The combined force causes the swarm to organize around the LED while maintaining inter-robot spacing.

Run:

```bash
cd ~/swarm_robotics/pattern_formation
argos3 -c pattern_formation.argos
```

### Exercise 3: Flocking

Controller:

```text
pattern_formation/Flocking.lua
```

Experiment:

```text
pattern_formation.argos
```

This controller extends circular pattern formation into collective motion:

- Robots first form around the red LED.
- After a fixed number of simulation steps, robots switch to the ambient light source.
- The Lennard-Jones force remains active throughout the experiment.
- The swarm moves as a group while preserving local spacing.

This demonstrates flocking without a leader: each robot follows local forces and the group-level behavior emerges from decentralized interactions.

Run:

```bash
cd ~/swarm_robotics/pattern_formation
argos3 -c pattern_formation.argos
```

## Project: Foraging with Forbidden Areas

Directory:

```text
foraging/
```

Controller:

```text
foraging/foraging_controller.lua
```

Experiment:

```text
foraging.argos
```

The project objective is to maximize the number of items transported from the food source to the nest while avoiding a forbidden area.

The environment contains:

- A black food source.
- A white nest area.
- A dark gray forbidden area.
- A yellow light above the food source.

The ARGoS loop function handles item pickup and delivery automatically:

- A robot picks up an item when it reaches the food source.
- A robot delivers an item when it reaches the nest while carrying one.
- A robot loses the item if it enters the forbidden area.

### Current Strategy

The controller is a finite-state behavior system:

```text
search_food
go_nest
danger_beacon
nest_beacon
escape_forbidden
```

Behavior summary:

- Robots search for food by following the yellow light.
- When food is detected, robots switch to carrying mode and turn blue.
- Carrying robots search for the nest using exploration, peer interaction, danger avoidance, and nest beacons.
- Robots that reach the forbidden area become red danger beacons.
- Robots that reach the nest become white nest beacons.
- Carrying robots are attracted to nest beacons and repelled from danger beacons.

Signals used through range-and-bearing:

```text
1 -> carrying item
2 -> danger beacon
3 -> nest beacon
```

The controller also includes a cooperative search component based on Lennard-Jones interaction among carrying robots. This helps avoid all robots following the same path and encourages distributed exploration.

### Running the Project

Build the loop function first:

```bash
cd ~/swarm_robotics/foraging
mkdir -p build
cd build
cmake ../src
make
export ARGOS_PLUGIN_PATH=$ARGOS_PLUGIN_PATH:$HOME/swarm_robotics/foraging/build/
```

Then run:

```bash
cd ~/swarm_robotics/foraging
argos3 -c foraging.argos
```

Performance is written to:

```text
foraging/output.txt
```

The file reports the number of items collected over time.

## Design Principles

The implementations are based on common swarm robotics principles:

- Local sensing only.
- Decentralized control.
- Homogeneous robot behavior.
- Emergent group-level organization.
- Implicit communication through position and signals.
- Positive feedback for aggregation and collective motion.
- Repulsion fields for obstacle and danger avoidance.

## Notes

- Most controllers are intentionally simple and parameter-driven so behaviors can be tuned from constants at the top of each Lua file.
- ARGoS sensors report angles in robot-local coordinates, with angle `0` corresponding to the robot's front direction.
- Ground colors are inferred from grayscale sensor values, where black is close to `0` and white is close to `1`.
- The foraging controller tracks carrying state internally, but the authoritative item count is maintained by the C++ loop function.
