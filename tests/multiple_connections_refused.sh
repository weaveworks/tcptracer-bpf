#!/bin/bash

readonly nonlistening_port=65530

for _ in $(seq 1 "$1"); do
    wget -q http://127.0.0.1:"${nonlistening_port}" &>/dev/null
done

exit 0
