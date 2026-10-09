from setuptools import find_packages, setup

package_name = 'apriltag_nav'

setup(
    name=package_name,
    version='0.0.1',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Emanuele',
    maintainer_email='info@tartanrobotics.com',
    description='TFind and Navigate close to an apriltag',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'apriltag_nav = apriltag_nav.apriltag_nav:main',
        ],
    },
)
