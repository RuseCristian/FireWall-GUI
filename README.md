# Firewall GUI Project

## Introduction

This project is a Firewall GUI developed in Debian using Bash and the Whiptail library. The interface includes 12 buttons, each serving a different function for managing firewall rules and configurations.

## Features

### 1. Append Rule
The **Append Rule** button allows users to add a new firewall rule to the end of a selected chain within the existing firewall configuration.

- **Chains**: Users can select from available chains, including user-defined ones.
- **Protocols**: Options include Transmission Control Protocol (TCP), User Datagram Protocol (UDP), and ALL protocols.
- **Details**: If TCP or UDP is selected, users can specify the destination port, source IP address, and destination IP address. The traffic can be accepted, dropped, or rejected.

### 2. Insert Rule at Specific Position
The **Insert Rule** button enables users to insert a new rule at a user-defined position within the selected chain, similar to the append rule functionality.

### 3. Add Custom Rule
The **Add Custom Rule** button allows users to input and apply custom iptables rules. The script checks the syntax of the custom rule before applying it to ensure compliance.

### 4. Delete Rule
The **Delete Rule** button enables users to remove a specific rule from the iptables firewall configuration by selecting its index.

### 5. Display Rules
The **Display Rules** button shows all the rules that have been previously added to the firewall configuration.

### 6. Block All SSH Connections
The **Block All SSH Connections** button adds a rule to prevent any incoming SSH (Secure Shell) connections, enhancing security by blocking remote access.

### 7. Block All Connections from IP
The **Block All Connections from IP** button allows users to block all incoming connections from a specified IP address. The IP address is validated to ensure it follows the correct IPv4 format.

### 8. Block All Connections from IP Temporarily
This button works like the previous one but with a time window, temporarily blocking all incoming connections from a specified IP address.

### 9. Limit Rate Connection from IP
The **Limit Rate Connection from IP** button imposes restrictions on the rate of incoming connections from a specified IP address. Users define the maximum number of connections allowed within a specified time window.

### 10. Reset Firewall
The **Reset Firewall** button resets the firewall to its default state, removing all custom rules.

### 11. Network Statistics
The **Network Statistics** button provides an overview of the network traffic statistics gathered from the iptables configuration, offering insights into traffic patterns and usage.

## Screenshots
Firewall GUI Screenshot([Firewall.pdf](https://github.com/RuseCristian/FireWall-GUI/files/15442458/Firewall.pdf)
[]())

## Installation and Usage

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/RuseCristian/FireWall-GUI.git
   cd firewall-gui
