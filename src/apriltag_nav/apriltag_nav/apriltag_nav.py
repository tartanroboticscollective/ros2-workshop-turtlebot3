"""Find an AprilTag and print its transform and a nearby Nav2 goal."""

import math

from apriltag_find_interfaces.srv import FindTag

from action_msgs.msg import GoalStatus
from nav2_msgs.action import NavigateToPose

import rclpy
from rclpy.node import Node
from rclpy.time import Time
from rclpy.action import ActionClient

from tf2_ros import Buffer, TransformException, TransformListener


class AprilTagNav(Node):

    def __init__(self):
        super().__init__('apriltag_nav')
        self.declare_parameter('tag_id', 0)
        self.declare_parameter('tag_distance', 0.3)
        self.tf_buffer = Buffer(node=self)
        self.tf_listener = TransformListener(self.tf_buffer, self)
        self.find_client = self.create_client(
            FindTag, '/apriltag_find_service/find_tag'
        )
        self.nav_client =ActionClient(self, NavigateToPose, '/navigate_to_pose')
        self.nav_goal = None
        self.nav_goal_check = None

    def _wait_action(self, action):
        while rclpy.ok() and not action.done():
            rclpy.spin_until_future_complete(self, action, timeout_sec=0.1)
        if not action.done():
            raise RuntimeError('Killd while processing action')
        return action.result()

    def _navigation_goal(self, tag_id, tag_tf):
        try:
            robot = self.tf_buffer.lookup_transform(
                tag_tf.header.frame_id, 'base_footprint', Time()
            ).transform.translation
        except TransformException as error:
            self.get_logger().error(f'Cannot locate the robot: {error}')
            return False

        # get distance from detcted tag and robot base
        position = tag_tf.transform.translation
        dx, dy = position.x - robot.x, position.y - robot.y
        separation = math.hypot(dx, dy)
        distance = self.get_parameter('tag_distance').value
        if separation == 0.0 or distance < 0.0:
            self.get_logger().error('Cannot compute a valid approach goal')
            return False

        # To nav action
        goal = NavigateToPose.Goal()
        goal.pose.header.frame_id = tag_tf.header.frame_id
        goal.pose.header.stamp = self.get_clock().now().to_msg()
        goal.pose.pose.position.x = position.x - distance * dx / separation
        goal.pose.pose.position.y = position.y - distance * dy / separation
        yaw = math.atan2(dy, dx)
        goal.pose.pose.orientation.z = math.sin(yaw / 2.0)
        goal.pose.pose.orientation.w = math.cos(yaw / 2.0)

        self.nav_goal = self.nav_client.send_goal_async(goal)

        self.nav_goal_check = self._wait_action(self.nav_goal)
        if not self.nav_goal_check.accepted:
            self.get_logger().error("Nav2 reject goal")
            self.nav_goal_check = None
            return False

        nav_result = self.nav_goal_check.get_result_async()
        result = self._wait_action(nav_result)
        self.nav_goal_check = None

        if result.status != GoalStatus.STATUS_SUCCEEDED:
            self.get_logger().error(
                f'Navigation failed (status {result.status}): '
                f'{result.result.error_msg}'
            )
            return False

        self.get_logger().info(f'!! Reached tag {tag_id} !!')
        return True

    def navigate(self):
        if not self.find_client.wait_for_service(timeout_sec=10.0):
            self.get_logger().error('AprilTag find service is unavailable')
            return False

        if not self.nav_client.wait_for_server(timeout_sec=10.0):
            self.get_logger().error('Nav2 navigate_to_pose action is unavailable')
            return False

        tag_id = self.get_parameter('tag_id').value
        self.get_logger().info(f'Searching for tag {tag_id}')


        searched_tag = self.find_client.call_async(FindTag.Request(tag_id=tag_id))
        rclpy.spin_until_future_complete(self, searched_tag)
        if not searched_tag.done():
            return False
        
        response = searched_tag.result()

        if response is None or not response.found:
            self.get_logger().error(f'Tag {tag_id} was not found')
            return False

        tag_tf = response.tag_transform

        return self._navigation_goal(tag_id,tag_tf)


def main(args=None):
    rclpy.init(args=args)
    node = AprilTagNav()
    try:
        node.navigate()
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
