"""Service for querying detected AprilTags in the simulation."""

import rclpy
from rclpy.clock import Clock
from rclpy.qos import QoSProfile
from geometry_msgs.msg import TwistStamped
from apriltag_msgs.msg import AprilTagDetectionArray
from apriltag_sim_interfaces.srv import FindTag
from rclpy.node import Node


ANGULAR_VELOCITY = 0.8


class AprilTagSimService(Node):
    """Check for visible tag (with input number) and return its position and find status."""

    def __init__(self):
        super().__init__('apriltag_sim_service')
        self._tag_frames = {
            f'tag36h11_{tag_id}': tag_id for tag_id in range(4)
        }

        # for Apriltag detection topic
        self._detected_tags = {}
        self.rate = self.create_rate(1)
        self.create_subscription(
            AprilTagDetectionArray, '/detections', self._on_detections, 10
        )

        self.create_service(FindTag, 'find_tag', self._srv_find_tag)
        self.get_logger().info('FindTag service ready: /find_tag')

        # turtlebot cmd vel
        self.tb_cmdvel_pub = self.create_publisher(TwistStamped, 'cmd_vel', QoSProfile(depth=10))

    def _on_detections(self, message):
        for tag in message.detections: 
            self._detected_tags[tag.id] = tag.centre
        self.get_logger().warn(f'Lenght {len(self._detected_tags.keys())}')
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

    def _srv_find_tag(self, request, response):
        tag_id = request.tag_id

        # Rotate turtlebot on place until the tag number is detected
        while (not self._tag_detected(tag_id)):
            self._rotate_turtlebot()
            self.rate.sleep()

        # Tag found!
        self._stop_turtlebot()
        self.get_logger().info(f'Found Tag {tag_id}', once=True)

        # Service Output
        position = self._tag_positions.get(tag_id)

        response.found = True
        if response.found:
            response.tag_position.x = position.x
            response.tag_position.y = position.y
        return response


def main(args=None):
    rclpy.init(args=args)
    node = AprilTagSimService()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
