#!/bin/bash

# Update and Upgrade Packages
apt update -y && apt upgrade -y

# Create Bridge br0 for red namespace
ip link add br0 type bridge
ip link set br0 up
ip addr add 10.11.0.1/24 dev br0

# Create veth pair for red namespace
ip link add v-red type veth peer name v-red-ns

# Create and configure red namespace
ip netns add red
ip link set v-red master br0
ip link set v-red-ns netns red
ip link set v-red up
ip netns exec red ip link set v-red-ns up
ip netns exec red ip addr add 10.11.0.2/24 dev v-red-ns
ip netns exec red ip route add default via 10.11.0.1
ip netns exec red ping 10.11.0.1 -c 3

# Create Bridge br1 for blue namespace
ip link add br1 type bridge
ip link set br1 up
ip addr add 10.12.0.1/24 dev br1

# Create veth pair for blue namespace
ip link add v-blue type veth peer name v-blue-ns
ip link set v-blue up

# Create and configure blue namespace
ip netns add blue
ip link set v-blue master br1
ip link set v-blue-ns netns blue
ip netns exec blue ip link set v-blue-ns up
ip netns exec blue ip addr add 10.12.0.2/24 dev v-blue-ns
ip netns exec blue ip route add default via 10.12.0.1
ip netns exec blue ping 10.12.0.1 -c 3

# Create router namespace
ip netns add router

# Connect router to br0
ip link add vr-red type veth peer name vr-red-ns
ip link set vr-red master br0
ip link set vr-red up
ip link set vr-red-ns netns router
ip netns exec router ip link set vr-red-ns up

# Connect router to br1
ip link add vr-blue type veth peer name vr-blue-ns
ip link set vr-blue master br1
ip link set vr-blue up
ip link set vr-blue-ns netns router
ip netns exec router ip link set vr-blue-ns up

# Assign IP addresses to router
ip netns exec router ip addr add 10.11.0.3/24 dev vr-red-ns
ip netns exec router ip addr add 10.12.0.3/24 dev vr-blue-ns

# Enable IP forwarding
ip netns exec router sysctl -w net.ipv4.ip_forward=1

# Configure iptables rules for forwarding
iptables --append FORWARD --in-interface br0 --jump ACCEPT
iptables --append FORWARD --out-interface br0 --jump ACCEPT
iptables --append FORWARD --in-interface br1 --jump ACCEPT
iptables --append FORWARD --out-interface br1 --jump ACCEPT

# Test connectivity
ip netns exec red ping 10.12.0.2 -c 5
ip netns exec router ping 10.12.0.2 -c 3
ip netns exec router ping 10.11.0.2 -c 3
