# ROS 2 Jazzy Turtlebot3 Development
ROS2 Jazzy turtlebot3 dev container adapted from [docker-for-robotics](https://github.com/2b-t/docker-for-robotics) by [Tobit Flatscher](https://github.com/2b-t)

## 0. Set-up
This dev environment uses [`vcstool`](http://wiki.ros.org/vcstool) to pull the dependencies repos. Please import them with the following command before building the docker:

```
$ cd src/
$ vcs import < .repos   
```


## 1. Running

### CLI

In order to be able to run **graphical user interfaces** from inside the Docker you might have to type

```bash
$ xhost +
```

Either **run the Docker** manually with

```bash
$ cd ros2-workshop-turtlebot3/
$ docker compose -f docker/docker-compose-gui.yml up
```

and then connect to the running Docker

```bash
$ cd ros2-workshop-turtlebot3/
$ docker exec -it ros2_docker bash
```