#!/usr/bin/env python3
"""Publish a Gazebo model's visual geometry as markers.

Lets the simulated world be seen in Foxglove without running the Gazebo
GUI. Every <visual> in the model SDF becomes a marker; meshes are sent as
package:// URIs, which foxglove_bridge serves to the browser.

Markers are published in a 'world' frame placed at the Gazebo world
origin. The odom frame starts at the robot's spawn pose, not at the world
origin, so a static transform between the two keeps the geometry aligned
with the laser scan.
"""

import math
import os
import xml.etree.ElementTree as ET

from ament_index_python.packages import get_package_share_directory
from geometry_msgs.msg import Point, TransformStamped
import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile
from tf2_ros import StaticTransformBroadcaster
from visualization_msgs.msg import Marker, MarkerArray

PACKAGE = 'turtlebot3_gazebo'


def rpy_to_quaternion(roll, pitch, yaw):
    cy, sy = math.cos(yaw * 0.5), math.sin(yaw * 0.5)
    cp, sp = math.cos(pitch * 0.5), math.sin(pitch * 0.5)
    cr, sr = math.cos(roll * 0.5), math.sin(roll * 0.5)
    return (
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy,
    )


def parse_pose(element):
    text = element.findtext('pose') if element is not None else None
    values = [float(v) for v in text.split()] if text else []
    values += [0.0] * (6 - len(values))
    return values


class WorldMarkers(Node):

    def __init__(self):
        super().__init__('world_markers')
        self.declare_parameter('model', 'turtlebot3_world')
        self.declare_parameter('frame_id', 'world')
        self.declare_parameter('odom_frame', 'odom')
        self.declare_parameter('x_pose', -2.0)
        self.declare_parameter('y_pose', -0.5)
        self.declare_parameter('ground_size', 20.0)
        model = self.get_parameter('model').value
        self.frame_id = self.get_parameter('frame_id').value

        self.publish_world_transform()

        # Latched, so clients connecting later still receive the world
        qos = QoSProfile(depth=1, durability=DurabilityPolicy.TRANSIENT_LOCAL)
        self.publisher = self.create_publisher(
            MarkerArray, 'world_markers', qos
        )

        sdf = os.path.join(
            get_package_share_directory(PACKAGE), 'models', model, 'model.sdf'
        )
        markers = self.build(sdf)
        self.publisher.publish(markers)
        self.get_logger().info(
            f'Published {len(markers.markers)} markers from {model}'
        )

    def publish_world_transform(self):
        """Place the world origin relative to odom.

        odom starts at the robot's spawn pose, so the world origin sits at
        the negative of that pose in odom coordinates.
        """
        transform = TransformStamped()
        transform.header.stamp = self.get_clock().now().to_msg()
        transform.header.frame_id = self.get_parameter('odom_frame').value
        transform.child_frame_id = self.frame_id
        transform.transform.translation.x = -float(
            self.get_parameter('x_pose').value
        )
        transform.transform.translation.y = -float(
            self.get_parameter('y_pose').value
        )
        transform.transform.rotation.w = 1.0

        self.static_tf = StaticTransformBroadcaster(self)
        self.static_tf.sendTransform(transform)

    def ground_marker(self):
        """Stand in for the world's ground plane.

        Parts of the model are authored below z=0 and are meant to be
        hidden by the ground, which lives in a separate Gazebo model.
        """
        marker = Marker()
        marker.header.frame_id = self.frame_id
        marker.ns = 'world'
        marker.type = Marker.CUBE
        marker.action = Marker.ADD
        marker.pose.position.z = -0.005
        marker.pose.orientation.w = 1.0
        size = float(self.get_parameter('ground_size').value)
        marker.scale.x = marker.scale.y = size
        marker.scale.z = 0.01
        marker.color.r = marker.color.g = marker.color.b = 0.4
        marker.color.a = 1.0
        return marker

    def build(self, sdf_path):
        root = ET.parse(sdf_path).getroot()
        array = MarkerArray()

        if self.get_parameter('ground_size').value > 0.0:
            marker = self.ground_marker()
            marker.id = 0
            array.markers.append(marker)

        for link in root.iter('link'):
            link_pose = parse_pose(link)

            for visual in link.iter('visual'):
                geometry = visual.find('geometry')
                if geometry is None or len(geometry) == 0:
                    continue

                marker = self.make_marker(geometry[0], visual, link_pose)
                if marker is not None:
                    marker.id = len(array.markers)
                    array.markers.append(marker)

        return array

    def make_marker(self, shape, visual, link_pose):
        marker = Marker()
        marker.header.frame_id = self.frame_id
        marker.ns = 'world'
        marker.action = Marker.ADD

        pose = parse_pose(visual)
        marker.pose.position.x = link_pose[0] + pose[0]
        marker.pose.position.y = link_pose[1] + pose[1]
        marker.pose.position.z = link_pose[2] + pose[2]
        quaternion = rpy_to_quaternion(pose[3], pose[4], pose[5])
        (
            marker.pose.orientation.x,
            marker.pose.orientation.y,
            marker.pose.orientation.z,
            marker.pose.orientation.w,
        ) = quaternion

        marker.color.r = marker.color.g = marker.color.b = 0.75
        marker.color.a = 1.0

        if shape.tag == 'cylinder':
            marker.type = Marker.CYLINDER
            radius = float(shape.findtext('radius', '0.1'))
            marker.scale.x = marker.scale.y = radius * 2.0
            marker.scale.z = float(shape.findtext('length', '0.1'))
        elif shape.tag == 'box':
            marker.type = Marker.CUBE
            size = [float(v) for v in shape.findtext('size', '1 1 1').split()]
            marker.scale.x, marker.scale.y, marker.scale.z = size
        elif shape.tag == 'sphere':
            marker.type = Marker.SPHERE
            radius = float(shape.findtext('radius', '0.1'))
            marker.scale.x = marker.scale.y = marker.scale.z = radius * 2.0
        elif shape.tag == 'mesh':
            # The meshes are sent as explicit triangles rather than as
            # mesh_resource URIs. They declare inches and Y_UP, which
            # viewers apply inconsistently; converting here means every
            # viewer draws them where Gazebo does.
            marker.type = Marker.TRIANGLE_LIST
            marker.scale.x = marker.scale.y = marker.scale.z = 1.0
            scale = [
                float(v) for v in shape.findtext('scale', '1 1 1').split()
            ]
            uri = shape.findtext('uri', '')
            marker.points, colour = self.load_mesh(uri, scale)
            if not marker.points:
                return None
            marker.color.r, marker.color.g, marker.color.b = colour
        else:
            return None

        return marker

    def load_mesh(self, uri, scale):
        """Read a COLLADA mesh as triangles in metres, plus its colour."""
        path = os.path.join(
            get_package_share_directory(PACKAGE),
            'models',
            uri.replace('model://', ''),
        )
        if not os.path.isfile(path):
            self.get_logger().warning(f'Mesh not found: {path}')
            return [], (0.75, 0.75, 0.75)

        ns = {'c': 'http://www.collada.org/2005/11/COLLADASchema'}
        collada = ns['c']
        root = ET.parse(path).getroot()

        unit = root.find('.//c:unit', ns)
        metre = float(unit.get('meter', '1')) if unit is not None else 1.0

        # <vertices> names the source holding POSITION data
        source_id = None
        vertices = root.find('.//c:vertices', ns)
        for inp in vertices.findall('c:input', ns):
            if inp.get('semantic') == 'POSITION':
                source_id = inp.get('source').lstrip('#')

        coords = []
        for source in root.iter(f'{{{collada}}}source'):
            if source.get('id') == source_id:
                coords = [
                    float(v)
                    for v in source.find('c:float_array', ns).text.split()
                ]

        points = []
        for triangles in root.iter(f'{{{collada}}}triangles'):
            indices = [int(i) for i in triangles.find('c:p', ns).text.split()]
            for index in indices:
                point = Point()
                point.x = coords[index * 3] * metre * scale[0]
                point.y = coords[index * 3 + 1] * metre * scale[1]
                point.z = coords[index * 3 + 2] * metre * scale[2]
                points.append(point)

        colour = root.find('.//c:diffuse/c:color', ns)
        if colour is not None:
            rgb = [float(v) for v in colour.text.split()][:3]
        else:
            rgb = [0.75, 0.75, 0.75]

        return points, rgb


def main():
    rclpy.init()
    node = WorldMarkers()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
