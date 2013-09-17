#!/bin/bash
ps xa | grep postgres: | grep discourse | grep -v grep | awk '{print $1}' | sudo xargs kill