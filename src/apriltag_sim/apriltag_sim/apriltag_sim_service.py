"""Service for querying detected AprilTags in the simulation."""

import threading

from apriltag_msgs.msg import AprilTagDetectionArray

from apriltag_sim_interfaces.srv import FindTag

from geometry_msgs.msg import TwistStamped

import rclpy
from rclpy.callback_groups import MutuallyExclusiveCallbackGroup
from rclpy.clock import Clock
from rclpy.executors import MultiThreadedExecutor
from rclpy.node import Node
from rclpy.qos import QoSProfile

ANGULAR_VELOCITY = 0.8


class AprilTagSimService(Node):
    """Check for visible tag and return its position and find status."""

    def __init__(self):
        """Initialise the AprilTag Detection Service."""
        super().__init__('apriltag_sim_service')
        self._tag_frames = {
            f'tag36h11_{tag_id}': tag_id for tag_id in range(4)
        }

        # for Apriltag detection topic
        self._detected_tags = {}

        self._tag_detection_group = MutuallyExclusiveCallbackGroup()
        self.rate = self.create_rate(5)
        self.create_subscription(
            AprilTagDetectionArray,
            '/detections',
            self._on_detections,
            10,
            callback_group=self._tag_detection_group,
        )

        self.create_service(
            FindTag, '/apriltag_sim_service/find_tag', self._srv_find_tag
        )
        self.get_logger().info('FindTag service ready: /find_tag')

        # turtlebot cmd vel
        self.tb_cmdvel_pub = self.create_publisher(
            TwistStamped, 'cmd_vel', QoSProfile(depth=10)
        )

    def _on_detections(self, message):
        for tag in message.detections:
            self._detected_tags[tag.id] = (tag.centre.x, tag.centre.y)
        # self.get_logger().warn(f'Lenght {len(self._detected_tags.keys())}')

    def _rotate_turtlebot(self):
        rot_msg = TwistStamped()
        rot_msg.header.stamp = Clock().now().to_msg()
        rot_msg.header.frame_id = ''
        rot_msg.twist.linear.x = 0.0
        rot_msg.twist.linear.y = 0.0
        rot_msg.twist.linear.z = 0.0

        rot_msg.twist.angular.x = 0.0
        rot_msg.twist.angular.y = 0.0
        rot_msg.twist.angular.z = ANGULAR_VELOCITY

        self.tb_cmdvel_pub.publish(rot_msg)

    def _stop_turtlebot(self):
        rot_msg = TwistStamped()
        rot_msg.header.stamp = Clock().now().to_msg()
        rot_msg.header.frame_id = ''
        rot_msg.twist.linear.x = 0.0
        rot_msg.twist.linear.y = 0.0
        rot_msg.twist.linear.z = 0.0

        rot_msg.twist.angular.x = 0.0
        rot_msg.twist.angular.y = 0.0
        rot_msg.twist.angular.z = 0.0

        self.tb_cmdvel_pub.publish(rot_msg)

    def _tag_detected(self, tag_id):
        return 0 <= tag_id <= 3 and tag_id in self._detected_tags.keys()

    def _search_tag(self, tag_id):
        # Rotate turtlebot on place until the tag number is detected
        while not self._tag_detected(tag_id):
            self._rotate_turtlebot()
            self.rate.sleep()
        # Tag found!
        self._stop_turtlebot()
        self.get_logger().info(f'Found Tag {tag_id}', once=True)

    def _srv_find_tag(self, request, response):
        self._detected_tags.clear()

        tag_id = request.tag_id

        if tag_id < 0 or tag_id > 3:
            self.get_logger().error(
                f'ID {tag_id} not allowed. Tags IDs allowed [0,3]'
            )
            response.found = False
            return response

        # thread to rotate tb and no blocking subscribers here
        self.tb_search_thread = threading.Thread(
            target=self._search_tag, args=(tag_id,), daemon=True
        )
        self.tb_search_thread.start()
        self.tb_search_thread.join()
        # Service Output
        position = self._detected_tags.get(tag_id)

        response.found = True
        if response.found:
            response.tag_position.x = position[0]
            response.tag_position.y = position[1]
        return response


def main(args=None):
    """Start the AprilTag service node."""
    rclpy.init(args=args)
    node = AprilTagSimService()

    multi_thread_exec = MultiThreadedExecutor(num_threads=2)
    multi_thread_exec.add_node(node)

    try:
        multi_thread_exec.spin()
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
