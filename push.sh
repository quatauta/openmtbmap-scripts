#!/bin/sh

ssh-add -l | fgrep -q $HOME/.ssh/id_rsa || ssh-add
bzr dpush git@github.com:quatauta/openmtbmap-scripts.git,branch=master
bzr push --overwrite