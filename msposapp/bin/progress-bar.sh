#!/usr/bin/env bash

progress-bar() {
  command=${1}
  while [ $? != "10" ]; do
  exec $command

  already_done() { for ((done=0; done<elapsed; done=done+1)); do printf "▇"; done }
  remaining() { for ((remain=elapsed; remain<duration; remain=remain+1)); do printf " "; done }
  percentage() { printf "| %s%%" $(( ((elapsed)*100)/(duration)*100/100 )); }
  clean_line() { printf "\r"; }

  for (( elapsed=1; elapsed<=duration; elapsed=elapsed+1 )); do
      already_done; remaining; percentage
      sleep 1
      clean_line
  done
  clean_line
  done
}
