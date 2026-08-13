# ROS 2 Jazzy Turtlebot3 Development
![License](https://img.shields.io/github/license/tartanroboticscollective/ros2-workshop-turtlebot3)
![ROS2 Version](https://img.shields.io/badge/ROS2-Jazzy%20Jalisco-brightgreen)
![Issues](https://img.shields.io/github/issues/tartanroboticscollective/ros2-workshop-turtlebot3)
![Latest Release](https://img.shields.io/github/v/tag/tartanroboticscollective/ros2-workshop-turtlebot3.svg)

A ROS 2 Jazzy workspace for the Turtlebot 3, in Docker. Runs on Linux,
macOS and Windows.


## 1. Requirements

- [Docker](https://docs.docker.com/get-started/get-docker/)
  (Docker Desktop on macOS and Windows)
- `git` and `tmux`
- A web browser

No ROS installation, X server or GPU is needed on your machine.


## 2. Quick start

```bash
git clone https://github.com/tartanroboticscollective/ros2-workshop-turtlebot3.git
cd ros2-workshop-turtlebot3
./start_sesh.sh
```

The first run downloads the image and imports the workspace sources, then
opens a tmux session and a browser tab at <http://localhost:8080> showing
the robot in Foxglove.

```
┌──────────────────────────────────┬─────────────────┐
│                                  │                 │
│          Main terminal           │     Teleop      │
│                                  │                 │
├──────────────────┬───────────────┼─────────────────┤
│      Zenoh       │    Viewer     │     Gazebo      │
└──────────────────┴───────────────┴─────────────────┘
```

- **Main terminal** — a shell inside the container
- **Teleop** — drive the robot with the keyboard; this pane starts focused
- **Zenoh** — the Zenoh router carrying ROS 2 traffic
- **Viewer** — the Foxglove bridge, or RViz2 with `--vnc`
- **Gazebo** — the simulator's log; there is no window unless you use `--vnc`

Drive the robot with the keys listed in the teleop pane and watch it move
in Gazebo.

Shut everything down with:

```bash
./start_sesh.sh --stop
```


## 3. Building the image yourself

```bash
./dev.sh
./start_sesh.sh --build
```

`dev.sh` builds the image and tags it `ros2-workshop-turtlebot3:local`.
`--build` launches that image instead of the prebuilt one. Everything else
works the same.


## 4. Viewers

By default the robot is visualised in [Foxglove](https://foxglove.dev) at
<http://localhost:8080>. The 3D view shows the simulated world, the robot,
its laser scan and the transform tree, and a side panel plots live
odometry. Gazebo runs without a window, so the simulation gets the
processor instead of drawing two 3D views.

For Gazebo's own window and RViz2 instead, use:

```bash
./start_sesh.sh --vnc
```

which serves both at <http://localhost:6080> and does not start Foxglove.

The viewer is [Lichtblick](https://github.com/lichtblick-suite/lichtblick),
served from its own container. It needs no account and no internet
connection once pulled. The layout in `config/foxglove-layout.json` is
loaded by the link the script opens; rearrange panels freely, or add your
own with `+`. Open that printed link rather than bookmarking
`localhost:8080` on its own, or the browser will use whatever layout it
last saved.

The world geometry comes from `config/world_markers.py`, which reads the
Gazebo model and publishes it on `/world_markers`.


## 5. Options

```
./start_sesh.sh [--build] [--vnc] [--x11] [--model NAME] [--stop] [--help]
```

| Flag | Effect |
| --- | --- |
| `--build` | Launch the image built by `./dev.sh`. |
| `--vnc` | Use Gazebo's window and RViz2 at `localhost:6080` instead of Foxglove. |
| `--x11` | Render GUIs on your own X server. Linux only. |
| `--model NAME` | Turtlebot 3 model: `burger` (default), `waffle`, `waffle_pi`. |
| `--stop` | Stop the container and kill the tmux session. |

Ports can be moved if something else is using them:

```bash
VIEWER_PORT=8081 ./start_sesh.sh
NOVNC_PORT=6081 ./start_sesh.sh --vnc
```


## 6. Working in the container

Open another shell in the running container:

```bash
docker exec -it ros2-workshop-turtlebot3 bash
```

Your `src/` directory is mounted at `/turtlebot_ws/src`, so edit code on
your machine and build it inside the container with these aliases:

| Alias | Runs |
| --- | --- |
| `rbuild` | rebuild the workspace with `colcon` |
| `rsource` | `source install/setup.bash` |
| `rclean` | clean the workspace build artifacts |


## 7. Troubleshooting

**The browser tab is blank.** Wait a few seconds and reload.

**Port 8080 is already in use.** Run `VIEWER_PORT=8081 ./start_sesh.sh`.

**Port 6080 is already in use.** Run
`NOVNC_PORT=6081 ./start_sesh.sh --vnc`.

**Foxglove shows the wrong panels, or "Waiting for image messages".** You
opened `localhost:8080` directly instead of the link the script prints,
so your browser used a layout it had saved. Reopen the printed link, which
ends in `?layoutUrl=...`, to load the workshop layout. The burger has no
camera, so an Image panel never fills in.

**Gazebo runs slowly.** Use the default Foxglove view rather than
`--vnc`, so nothing is rendered inside the container. On Linux, `--x11`
uses your graphics card.

**Start again from scratch.** Run `./start_sesh.sh --stop`, then relaunch.
The container is disposable; `src/` and `config/` live on your machine.
