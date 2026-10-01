"""Apriltag Sim package installation."""

from setuptools import find_packages, setup

package_name = 'apriltag_find'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        (
            'share/ament_index/resource_index/packages',
            ['resource/' + package_name],
        ),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='emanuele',
    maintainer_email='emanuele@todo.todo',
    description='AprilTag find service for TurtleBot3',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'apriltag_find_service = '
            'apriltag_find.apriltag_find_service:main',
        ],
    },
)
