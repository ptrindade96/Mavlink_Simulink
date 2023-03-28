#!/bin/bash
# Setup the workflow for the server

if [ ! -f ~/.bashrc.bak ]; then
    cp ~/.bashrc ~/.bashrc.bak
    # Store ID numbers
    echo -e '\n' >> ".bashrc"
    echo -e 'id_user=$(id -u)\n' >> ".bashrc"
    echo -e 'id_net=$((id_user-2000))\n' >> ".bashrc"
    # Configure Gazebo/ROS ports
    echo -e 'ros_port=$(($id_net+21400))\n' >> ".bashrc"
    echo -e 'gazebo_port=$(($id_net+22500))\n' >> ".bashrc"
    echo -e 'console_port=$(($id_net+23500))\n'  >> ".bashrc"
    echo -e 'cpf_broadcast_port=$(($id_net+24500))\n' >> ".bashrc"
    echo -e 'export PX4_START_PORT=$((25000+100*$id_net))\n' >> ".bashrc"
    echo -e 'export ROS_MASTER_URI=http://localhost:$ros_port\n'  >> ".bashrc"
    echo -e 'export GAZEBO_MASTER_URI=http://localhost:$gazebo_port'  >> ".bashrc"
    echo -e 'alias 3dTiger="/opt/TurboVNC/bin/vncserver -kill :$id_net; /opt/TurboVNC/bin/vncserver -vgl -wm mate-session :$id_net"'  >> ".bashrc"
fi

source .bashrc
