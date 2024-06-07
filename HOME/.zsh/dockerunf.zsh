del_stopped(){
	local name=$1
	local state
	state=$(docker inspect --format "{{.State.Running}}" "$name" 2>/dev/null)

	if [[ "$state" == "false" ]]; then
		docker rm "$name"
	fi
}

rstudio(){
	del_stopped rstudio

	docker run -d \
		-v /etc/localtime:/etc/localtime:ro \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v "${HOME}/fastly-logs:/root/fastly-logs" \
		-v /dev/shm:/dev/shm \
		-e "DISPLAY=unix${DISPLAY}" \
		-e QT_DEVICE_PIXEL_RATIO \
		--name rstudio \
		rstudio
}
