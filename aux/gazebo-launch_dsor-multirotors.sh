#!/bin/bash
# run multiple instances of the 'px4' binary, with the gazebo SITL simulation
# It assumes px4 is already built, with 'make px4_sitl_default gazebo'

# The simulator is expected to send to TCP port 4560+i for i in [0, N-1]
# For example gazebo can be run like this:
#./Tools/gazebo_sitl_multiple_run.sh -n 10 -m iris

function cleanup() {
	pkill -x -U $USER px4
	pkill -U $USER gzclient
	pkill -U $USER gzserver
}

function spawn_model() {
	MODEL=$1
	N=$2 #Instance Number
	X=$3
	Y=$4
	Y=${Y:=0.0}
	X=${X:=$((3*${N}))}

	SUPPORTED_MODELS=("iris" "plane" "standard_vtol" "rover" "r1_rover" "typhoon_h480")
	if [[ " ${SUPPORTED_MODELS[*]} " != *"$MODEL"* ]];
	then
		echo "ERROR: Currently only vehicle model $MODEL is not supported!"
		echo "       Supported Models: [${SUPPORTED_MODELS[@]}]"
		trap "cleanup" SIGINT SIGTERM EXIT
		exit 1
	fi

	working_dir="$build_path/instance_$n"
	[ ! -d "$working_dir" ] && mkdir -p "$working_dir"

	pushd "$working_dir" &>/dev/null
	echo "starting instance $N in $(pwd)"
	../bin/px4 -i $N -d "$build_path/etc" -w sitl_${MODEL}_${N} -s etc/init.d-posix/rcS >out.log 2>err.log &
	python3 ${src_path}/Tools/sitl_gazebo/scripts/jinja_gen.py ${src_path}/Tools/sitl_gazebo/models/${MODEL}/${MODEL}.sdf.jinja ${src_path}/Tools/sitl_gazebo --mavlink_tcp_port $((${PX4_START_PORT}+${N})) --mavlink_udp_port $((14540+${N})) --mavlink_id $((1+${N})) --gst_udp_port $((5600+${N})) --video_uri $((5600+${N})) --mavlink_cam_udp_port $((14530+${N})) --output-file /tmp/${MODEL}_${N}.sdf

	echo "Spawning ${MODEL}_${N} at ${X} ${Y}"

	gz model --spawn-file=/tmp/${MODEL}_${N}.sdf --model-name=${MODEL}_${N} -x ${X} -y ${Y} -z 0.83

	popd &>/dev/null

}

function configure_simulation() {
	px4_conf_file_dir=$1

	sed -i 's/simulator_tcp_port=$((4560+px4_instance))/simulator_tcp_port=$(('"${PX4_START_PORT}"'+px4_instance))/g' ${px4_conf_file_dir}/px4-rc.simulator
	sed -i 's/param set-default COM_RC_IN_MODE 1/param set-default COM_RC_IN_MODE 1\nparam set-default COM_RCL_EXCEPT 4/g' ${px4_conf_file_dir}/rcS
	sed 's/udp_offboard_port_local=$((14580+px4_instance))/udp_offboard_port_local=$(('"${PX4_START_PORT}"'+20+px4_instance))/g' ${px4_conf_file_dir}/px4-rc.mavlink > ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/udp_onboard_payload_port_local=$((14280+px4_instance))/udp_onboard_payload_port_local=$(('"${PX4_START_PORT}"'+40+px4_instance))/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/udp_onboard_gimbal_port_local=$((13030+px4_instance))/udp_onboard_gimbal_port_local=$(('"${PX4_START_PORT}"'+60+px4_instance))/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/udp_gcs_port_local=$((18570+px4_instance))/udp_gcs_port_local=$(('"${PX4_START_PORT}"'+80+px4_instance))\ntarget_ip=TEMPLATE_IP/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/mavlink start -x -u $udp_gcs_port_local -r 4000000 -f/mavlink start -x -u $udp_gcs_port_local -r 4000000 -f -t $target_ip/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/mavlink start -x -u $udp_offboard_port_local -r 4000000 -f -m onboard -o $udp_offboard_port_remote/mavlink start -x -u $udp_offboard_port_local -r 60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s POSITION_TARGET_LOCAL_NED -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 50 -s LOCAL_POSITION_NED -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s GLOBAL_POSITION_INT -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 50 -s ATTITUDE -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s ATTITUDE_QUATERNION -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s ATTITUDE_TARGET -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s SERVO_OUTPUT_RAW_0 -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s RC_CHANNELS -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s OPTICAL_FLOW_RAD -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s ODOMETRY -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s HIGHRES_IMU -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 1 -s HEARTBEAT -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s VFR_HUD -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 2 -s TIMESYNC -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i '/60000 -f -m onboard -o $udp_offboard_port_remote -t $target_ip/s/$/\nmavlink stream -r 0 -s ALTITUDE -u $udp_offboard_port_local/' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/mavlink start -x -u $udp_onboard_payload_port_local -r 4000 -f -m onboard -o $udp_onboard_payload_port_remote/mavlink start -x -u $udp_onboard_payload_port_local -r 4000 -f -m onboard -o $udp_onboard_payload_port_remote -t $target_ip/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	sed -i 's/mavlink start -x -u $udp_onboard_gimbal_port_local -r 400000 -m gimbal -o $udp_onboard_gimbal_port_remote/mavlink start -x -u $udp_onboard_gimbal_port_local -r 400000 -m gimbal -o $udp_onboard_gimbal_port_remote -t $target_ip/g' ${px4_conf_file_dir}/px4-rc.mavlink.template
	if [ -f "${px4_conf_file_dir}/airframes/10016_iris" ]; then
		echo -e '\nparam set-default MC_PITCHRATE_K 2\nparam set-default MC_ROLLRATE_K 2\nparam set-default MC_ROLL_P 8\nparam set-default MC_PITCH_P 8' >> "${px4_conf_file_dir}/airframes/10016_iris"
		echo -e '\nparam set-default MC_ROLLRATE_MAX 1600\nparam set-default MC_PITCHRATE_MAX 1600\nparam set-default MC_YAWRATE_MAX 1000' >> "${px4_conf_file_dir}/airframes/10016_iris"
	else
		if [ -f "${px4_conf_file_dir}/airframes/10016_gazebo-classic_iris" ]; then
			echo -e '\nparam set-default MC_PITCHRATE_K 2\nparam set-default MC_ROLLRATE_K 2\nparam set-default MC_ROLL_P 8\nparam set-default MC_PITCH_P 8' >> "${px4_conf_file_dir}/airframes/10016_gazebo-classic_iris"
			echo -e '\nparam set-default MC_ROLLRATE_MAX 1600\nparam set-default MC_PITCHRATE_MAX 1600\nparam set-default MC_YAWRATE_MAX 1000' >> "${px4_conf_file_dir}/airframes/10016_gazebo-classic_iris"
		fi
	fi
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
	echo "Usage: $0 [-a <ip_adress_of_controlling_computer>][-n <num_vehicles>] [-m <vehicle_model>] [-w <world>] [-s <script>]"
	echo "-s flag is used to script spawning vehicles e.g. $0 -s iris:3,plane:2"
	exit 1
fi

while getopts a:n:m:w:s:t:l: option
do
	case "${option}"
	in
		a) TARGET_IP=${OPTARG};;
		n) NUM_VEHICLES=${OPTARG};;
		m) VEHICLE_MODEL=${OPTARG};;
		w) WORLD=${OPTARG};;
		s) SCRIPT=${OPTARG};;
		t) TARGET=${OPTARG};;
		l) LABEL=_${OPTARG};;
	esac
done

num_vehicles=${NUM_VEHICLES:=1}
world=${WORLD:=empty}
target=${TARGET:=px4_sitl_default}
vehicle_model=${VEHICLE_MODEL:="iris"}
target_ip=${TARGET_IP:=127.0.0.1}
export PX4_SIM_MODEL=${vehicle_model}

echo ${SCRIPT}
src_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
build_path=${src_path}/build/${target}

# Change IP of Mavlink connection
if [ ! -f "${src_path}/ROMFS/px4fmu_common/init.d-posix/px4-rc.mavlink.template" ]; then
  # If the file px4-rc.mavlink.template does not exist, it is the first run.
  # Then some configurations must be made
  configure_simulation "${src_path}/ROMFS/px4fmu_common/init.d-posix"
fi
sed "s/TEMPLATE_IP/${target_ip}/g" ${src_path}/ROMFS/px4fmu_common/init.d-posix/px4-rc.mavlink.template > ${src_path}/ROMFS/px4fmu_common/init.d-posix/px4-rc.mavlink
echo $target_ip

working_dir=$(pwd)
cd $src_path
make $target
cd $working_dir

echo "killing running instances"
pkill -x px4 || true

sleep 1

source ${src_path}/Tools/setup_gazebo.bash ${src_path} ${src_path}/build/${target}

# To use gazebo_ros ROS2 plugins
if [[ -n "$ROS_VERSION" ]] && [ "$ROS_VERSION" == "2" ]; then
	ros_args="-s libgazebo_ros_init.so -s libgazebo_ros_factory.so"
else
	ros_args=""
fi

echo "Starting gazebo"
gzserver ${src_path}/Tools/sitl_gazebo/worlds/${world}.world --verbose $ros_args &
sleep 5

n=0
if [ -z ${SCRIPT} ]; then
	if [ $num_vehicles -gt 255 ]
	then
		echo "Tried spawning $num_vehicles vehicles. The maximum number of supported vehicles is 255"
		exit 1
	fi

	while [ $n -lt $num_vehicles ]; do
		spawn_model ${vehicle_model} $n
		n=$(($n + 1))
	done
else
	IFS=,
	for target in ${SCRIPT}; do
		target="$(echo "$target" | tr -d ' ')" #Remove spaces
		target_vehicle=$(echo $target | cut -f1 -d:)
		target_number=$(echo $target | cut -f2 -d:)
		target_x=$(echo $target | cut -f3 -d:)
		target_y=$(echo $target | cut -f4 -d:)

		if [ $n -gt 255 ]
		then
			echo "Tried spawning $n vehicles. The maximum number of supported vehicles is 255"
			exit 1
		fi

		m=0
		while [ $m -lt ${target_number} ]; do
			export PX4_SIM_MODEL=${target_vehicle}
			spawn_model ${target_vehicle}${LABEL} $n $target_x $target_y
			m=$(($m + 1))
			n=$(($n + 1))
		done
	done

fi
trap "cleanup" SIGINT SIGTERM EXIT

if [ ! ${HEADLESS} ]; then
	echo "Starting gazebo client"
	gzclient
fi

wait $!
