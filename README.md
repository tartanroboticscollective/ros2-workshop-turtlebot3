# ROS 2 Jazzy Turtlebot3 Development
![License](https://img.shields.io/github/license/tartanroboticscollective/ros2-workshop-turtlebot3)
![ROS2 Version](https://img.shields.io/badge/ROS2-Jazzy%20Jalisco-brightgreen)
![Issues](https://img.shields.io/github/issues/tartanroboticscollective/ros2-workshop-turtlebot3)
![Latest Release](https://img.shields.io/github/v/tag/tartanroboticscollective/ros2-workshop-turtlebot3.svg)

## 0. Set-up
This dev environment uses [`vcstool`](http://wiki.ros.org/vcstool) to pull the dependencies repos. Please import them with the following command before building the docker:

```
$ cd src/
$ vcs import < .repos
```


## 1. Running

### CLI

To run the tmux script:

```bash
$ ./start_sesh.sh
```

**OR**, to build and run the docker container manually, first:

```bash
$ ./dev.sh
```

Which will build and run zenoh in the container.

Then, to connect to the running Docker container:

```bash
$ docker exec -it ros2-workshop-turtlebot3 bash
```


## 2. FAQ

In order to be able to run **graphical user interfaces** from inside the Docker you might have to type

```bash
$ xhost +
```
