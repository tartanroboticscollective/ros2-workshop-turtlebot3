from glob import glob
import os

from setuptools import find_packages, setup

package_name = 'apriltag-sim'

model_files = [
    path for path in glob('models/apriltag-box/*') if os.path.isfile(path)
]

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*')),
        (os.path.join('share', package_name, 'worlds'), glob('worlds/*')),
        (os.path.join('share', package_name, 'models', 'apriltag-box'), model_files),
        (os.path.join('share', package_name, 'models', 'apriltag-box', 'meshes', 'tags'),glob('models/apriltag-box/meshes/tags/*')),
        (os.path.join('share', package_name, 'models', 'apriltag-box', 'meshes', 'walls'),glob('models/apriltag-box/meshes/walls/*')),
        (os.path.join('share', package_name, 'map'), glob('map/*')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='emanuele',
    maintainer_email='emanuele@todo.todo',
    description='Gazebo Sim AprilTag box world for TurtleBot3.',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
        ],
    },
)
