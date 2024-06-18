#!/bin/sh
echo -ne '\033c\033]0;face_tracker\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/prototype_twitch_head.x86_64" "$@"
