#!/bin/sh
echo "$$" > /tmp/die_loop.pid

while true;do
	sleep 1000000
done
