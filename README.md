# ROS 2 Jazzy Turtlebot3 Development
![License](https://img.shields.io/github/license/tartanroboticscollective/ros2-workshop-turtlebot3)
![ROS2 Version](https://img.shields.io/badge/ROS2-Jazzy%20Jalisco-brightgreen)
![Issues](https://img.shields.io/github/issues/tartanroboticscollective/ros2-workshop-turtlebot3)
![Latest Release](https://img.shields.io/github/v/tag/tartanroboticscollective/ros2-workshop-turtlebot3.svg)


## 0: Introduction

First Exercise

## 1: Simulation

Second Exercise

## 2: Apriltag

Final Exercise

### Real Turtlebot

Instructions for real TurtleBot

### Simulated Turtlebot

Run `./2_apriltagsim/dev_session.sh`

type `export TURTLEBOT3_MODEL=burger_cam`

type `rbuild`

type `rsource`

type `ros2 launch apriltag-sim apriltag_world.launch.xml`


---
### FAQ

In order to be able to run **graphical user interfaces** from inside the Docker you might have to type

```bash
$ xhost +
```
