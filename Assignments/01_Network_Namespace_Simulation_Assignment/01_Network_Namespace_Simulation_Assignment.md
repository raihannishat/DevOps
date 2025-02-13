# Linux Network Namespace and Bridging Configuration

## Overview
This document outlines the steps to set up network namespaces, virtual Ethernet (veth) pairs, and Linux bridges to create isolated networking environments. It also configures IP routing between namespaces using a router namespace and enables IP forwarding.

---

## Update and Upgrade Packages
```bash
apt update -y
apt upgrade -y
```
Updates the package lists and upgrades installed packages.

---

## Creating Network Namespaces and Bridges

### Step 1: Verify Existing Network Namespaces
```bash
ip netns
```
Lists existing network namespaces.

### Step 2: Create a Bridge `br0` for the `red` Namespace
```bash
ip link add br0 type bridge
ip link set br0 up
ip addr add 10.11.0.1/24 dev br0
```
Creates a new Linux bridge (`br0`), brings it up, and assigns an IP address.

### Step 3: Create a veth Pair for `red`
```bash
ip link add v-red type veth peer name v-red-ns
```
Creates a virtual Ethernet (veth) pair between the `red` namespace and the host.

### Step 4: Create and Configure the `red` Namespace
```bash
ip netns add red
ip link set v-red master br0
ip link set v-red-ns netns red
ip link set v-red up
```
Creates the `red` network namespace, attaches `v-red` to `br0`, and moves `v-red-ns` to `red`.

### Step 5: Configure `red` Namespace Networking
```bash
ip netns exec red ip link set v-red-ns up
ip netns exec red ip addr add 10.11.0.2/24 dev v-red-ns
ip netns exec red ip route add default via 10.11.0.1
ip netns exec red ping 10.11.0.1 -c 3
```
Brings up `v-red-ns` inside `red`, assigns an IP, sets a default route, and pings `br0`.

---

## Creating a Second Bridge and Namespace

### Step 6: Create a Bridge `br1` for the `blue` Namespace
```bash
ip link add br1 type bridge
ip link set br1 up
ip addr add 10.12.0.1/24 dev br1
```
Creates another bridge `br1` for the `blue` namespace.

### Step 7: Create a veth Pair for `blue`
```bash
ip link add v-blue type veth peer name v-blue-ns
ip link set v-blue up
```
Creates a veth pair for `blue`.

### Step 8: Create and Configure the `blue` Namespace
```bash
ip netns add blue
ip link set v-blue master br1
ip link set v-blue-ns netns blue
ip netns exec blue ip link set v-blue-ns up
ip netns exec blue ip addr add 10.12.0.2/24 dev v-blue-ns
ip netns exec blue ip route add default via 10.12.0.1
ip netns exec blue ping 10.12.0.1 -c 3
```
Creates `blue`, assigns a veth to `br1`, configures networking, and pings `br1`.

---

## Configuring a Router Namespace

### Step 9: Create the Router Namespace
```bash
ip netns add router
```
Creates a `router` namespace.

### Step 10: Connect `router` to `br0`
```bash
ip link add vr-red type veth peer name vr-red-ns
ip link set vr-red master br0
ip link set vr-red up
ip link set vr-red-ns netns router
ip netns exec router ip link set vr-red-ns up
```
Creates a veth pair, attaches `vr-red` to `br0`, and moves `vr-red-ns` to `router`.

### Step 11: Connect `router` to `br1`
```bash
ip link add vr-blue type veth peer name vr-blue-ns
ip link set vr-blue master br1
ip link set vr-blue up
ip link set vr-blue-ns netns router
ip netns exec router ip link set vr-blue-ns up
```
Creates a second veth pair, attaches `vr-blue` to `br1`, and moves `vr-blue-ns` to `router`.

### Step 12: Verify Interfaces in `router`
```bash
ip netns exec router ip link
```
Lists interfaces inside the `router` namespace.

---

## Configuring IP Addresses for the Router
```bash
ip netns exec router ip addr add 10.11.0.3/24 dev vr-red-ns
ip netns exec router ip addr add 10.12.0.3/24 dev vr-blue-ns
```
Assigns IP addresses to `router` for both `br0` and `br1`.

---

## Testing Connectivity
```bash
ip netns exec red ping 10.12.0.2 -c 5
ip netns exec router ping 10.12.0.2 -c 3
ip netns exec router ping 10.11.0.2 -c 3
```
Tests connectivity between namespaces.

---

## Enabling IP Forwarding and Configuring Firewall Rules

### Step 13: Enable Forwarding in the Kernel
```bash
ip netns exec router sysctl -w net.ipv4.ip_forward=1
```
Enables IP forwarding in the `router` namespace.

### Step 14: Configure IPTables Rules
```bash
iptables --append FORWARD --in-interface br0 --jump ACCEPT
iptables --append FORWARD --out-interface br0 --jump ACCEPT
iptables --append FORWARD --in-interface br1 --jump ACCEPT
iptables --append FORWARD --out-interface br1 --jump ACCEPT
```
Allows forwarding of packets between interfaces.

---

## Summary
- `br0` connects to `red`, and `br1` connects to `blue`.
- `router` namespace connects `br0` and `br1`.
- IP addresses and routes are configured.
- IP forwarding is enabled for routing.
- Firewall rules allow traffic forwarding.
- Network connectivity is verified with `ping`.

This setup allows `red` and `blue` to communicate through the `router` namespace.