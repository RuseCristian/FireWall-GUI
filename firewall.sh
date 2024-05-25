#!/bin/bash

# Check if iptables is installed
if ! command -v iptables &> /dev/null; then
    whiptail --msgbox "Iptables is not installed.\nPlease use the following command to istall iptables\n \nsudo apt-get install iptables" 10 60
    exit 1
fi

# Check if ran with sudo
if [ "$(id -u)" != "0" ]; then
    whiptail --msgbox "This script must be run as sudo (root) to manage iptables." 10 40
    exit 1
fi

validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$"
    
    if [[ $ip =~ $regex ]]; then
        if [[ $ip =~ "/" ]]; then
            # Extract the IP address and subnet mask parts
            ip_address="${ip%/*}"
            subnet_mask="${ip#*/}"
            
            IFS='.' read -ra octets <<< "$ip_address"
            
            # Check the validity of the IP address octets
            for octet in "${octets[@]}"; do
                if ! [[ $octet =~ ^[0-9]+$ ]] || ((octet < 0 || octet > 255)); then
                    return 1  # Invalid IPv4 address
                fi
            done
            
            # Check the validity of the subnet mask (1-32)
            if ! [[ $subnet_mask =~ ^[0-9]+$ ]] || ((subnet_mask < 1 || subnet_mask > 32)); then
                return 1  # Invalid subnet mask
            fi
        else
            IFS='.' read -ra octets <<< "$ip"
            for octet in "${octets[@]}"; do
                if ! [[ $octet =~ ^[0-9]+$ ]] || ((octet < 0 || octet > 255)); then
                    return 1  # Invalid IPv4 address
                fi
            done
        fi
        
        return 0  # Valid IPv4 address or address with subnet mask
    else
        return 1  # Invalid format
    fi
}



add_iptables_custom_rule() {
    while true; do
        rule=$(whiptail --title "Add iptables Rule" --inputbox "Enter the iptables rule:" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ $exitstatus -eq 0 ]; then
            $rule

            if [ $? -eq 0 ]; then
                whiptail --msgbox "Rule added:\n$rule" 10 40
                break  # Valid rule, exit the loop
            else
                whiptail --msgbox "The rule is not valid. Please provide a valid iptables rule." 10 60
            fi
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
            break  # User cancelled, exit the loop
        fi
    done
}


add_iptable_rule() {
    get_chains=$(iptables -S | awk -F ' ' '{print $2}' | sort -u)
    chain_array=($get_chains)

    chain_options=()
    for chain in "${chain_array[@]}"; do
        chain_options+=("$chain" "")
    done
    
    
    # chains
    while true; do
	    selected_chain=$(whiptail --title "Select a Chain" --menu "" 15 50 5 "${chain_options[@]}" 3>&1 1>&2 2>&3)
		return_code=$?
		
		
	    if [ $return_code -eq 0 ]; then
	    	break
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
	    fi
	done
	
	
	# position insert
	if [ "$1" == "insert" ]; then
	max_index=$(iptables -L $selected_chain -n --line-numbers | grep -c '^[0-9]\+')
	((max_index++))
		while true; do
			if [ "$max_index" -ge 2 ]; then
				insert_position=$(whiptail --title "Rule position index" --inputbox "Available options: 1 - $max_index" 10 40 3>&1 1>&2 2>&3)
			else
				insert_position=$(whiptail --title "Rule position index" --inputbox "Available options: 1" 10 40 3>&1 1>&2 2>&3)
			fi
			

			return_code=$?
			if [ $return_code -eq 0 ]; then
				if [ "$insert_position" -eq 1 ] || ([ "$max_index" -ge 2 ] && [ "$insert_position" -le "$max_index" ]); then
					break
			fi

	
			else
				whiptail --msgbox "Operation canceled." 10 60
				return
	
			fi
		done
	fi
		
		
		
	# protocol
	while true; do
		protocol_choice=$(whiptail --title "Select Protocols" --menu "Choose one or more protocols:" 15 60 5 \
			"TCP" "Transmission Control Protocol (TCP)" \
			"UDP" "User Datagram Protocol (UDP)" \
			"ALL" "All Protocols" 3>&1 1>&2 2>&3)

		return_code=$?

		if [ $return_code -eq 0 ]; then
		    break
		else
		    whiptail --msgbox "Operation canceled." 10 60
		 	return 
		fi
	done

	if [ $protocol_choice != "ALL" ]; then	
		# Input for the --dport option
		while true; do
			dport_input=$(whiptail --title "Destination Port (dport)" --inputbox "Leave empty for no port restriction\nEnter a single port or a range (e.g., 80 or 1000:2000):" 10 60 "$default_dport" 3>&1 1>&2 2>&3)
			return_code=$?

			if [ $return_code -eq 0 ]; then
			    # User confirmed the input
			    if [ -n "$dport_input" ]; then
				if [[ $dport_input =~ ^[0-9]+:[0-9]+$ ]]; then
				    # Check if the input is a valid port range
				    IFS=':' read -ra ports <<< "$dport_input"
				    start_port="${ports[0]}"
				    end_port="${ports[1]}"

				    if ((start_port >= 0 && start_port <= 65535)) && ((end_port >= 0 && end_port <= 65535)); then
				        break
				    else
				        whiptail --msgbox "Invalid port range. Please enter a valid port or range (0-65535)." 10 60
				        continue
				    fi
				elif [[ $dport_input =~ ^[0-9]+$ ]] && ((dport_input >= 0 && dport_input <= 65535)); then
				    # Input is a single valid port
				    break
				else
				    whiptail --msgbox "Invalid port or port range. Please enter a valid port or range (0-65535)." 10 60
				    continue
				fi
			    else
				break  # No port specified
			    fi
			else
			    whiptail --msgbox "Operation canceled." 10 60
			    return
			fi
		done
	fi


	# source address
	while true; do
		source_address=$(whiptail --title "Source IP Address" --inputbox "Leave empty for no source." 10 40 3>&1 1>&2 2>&3)

		return_code=$?
		if [ $return_code -eq 0 ]; then
			validate_ip "$source_address"
			ip_validation_status=$?

			if [ -z "$source_address" ] || [ $ip_validation_status -eq 0 ]; then
				break
			else
				whiptail --msgbox "Please Input a valid IP address." 10 60
			fi
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
		fi

	done


	# destination address
	while true; do
		destination_address=$(whiptail --title "Destination IP Address" --inputbox "Leave empty for no source." 10 40 3>&1 1>&2 2>&3)

		return_code=$?
		if [ $return_code -eq 0 ]; then
			validate_ip "$destination_address"
			ip_validation_status=$?

			if [ -z "$destination_address" ] || [ $ip_validation_status -eq 0 ]; then
				break
			else
				whiptail --msgbox "Please Input a valid IP address." 10 60
			fi
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
		fi

	done



	# action
	action_options=("ACCEPT" "Allow the traffic" "DROP" "Block the traffic" "REJECT" "Reject the traffic")
	while true; do
		selected_action=$(whiptail --title "Select an Action" --menu "Choose an action for the firewall rule:" 15 60 3 "${action_options[@]}" 3>&1 1>&2 2>&3)
		return_code=$?
		
		if [ $return_code -eq 0 ]; then
		    break
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
		fi
	done

	
	if [ "$1" == "append" ]; then
		iptables_command="iptables -A $selected_chain"
	elif [ "$1" == "insert" ]; then
		iptables_command="iptables -I $selected_chain $insert_position"
	fi
	
	protocol_choice="${protocol_choice//\"}"

	if [ "$protocol_choice" != "ALL" ]; then
		iptables_command+=" -p $protocol_choice"
	fi
	if [ -n "$dport_input" ]; then
		iptables_command+=" --dport $dport_input"
	fi
	if [ -n "$source_address" ]; then
		iptables_command+=" -s $source_address"
	fi
	if [ -n "$destination_address" ]; then
		iptables_command+=" -d $destination_address"
	fi
	iptables_command+=" -j $selected_action"

	while true; do
		if whiptail --title "Review iptables Command" --yesno "The iptables command is:\n\n$iptables_command\n\nIs this the desired command ?" 15 60; then
		    break
		else
		    whiptail --msgbox "Operation canceled." 10 60
		    return
		fi
	done

	$iptables_command
    if [ $? -eq 0 ]; then
        whiptail --msgbox "Rule added:\n$iptables_command" 10 40
        return
    else
        whiptail --msgbox "The rule is not valid. Please provide a valid iptables rule." 10 60
    fi
}




delete_iptables_rule() {

		get_chains=$(iptables -S | awk -F ' ' '{print $2}' | sort -u)
		chain_array=($get_chains)

		chain_options=()
		for chain in "${chain_array[@]}"; do
		    chain_options+=("$chain" "")
		done
		
		
		# chains
		while true; do
			selected_chain=$(whiptail --title "Select a Chain" --menu "" 15 50 5 "${chain_options[@]}" 3>&1 1>&2 2>&3)
			return_code=$?
			
			
			if [ $return_code -eq 0 ]; then
				break
			else
				whiptail --msgbox "Operation canceled." 10 60
				return
			fi
		done
		
		max_index=$(iptables -L $selected_chain -n --line-numbers | grep -c '^[0-9]\+')
		while true; do
            rule_number=$(whiptail --title "Delete iptables Rule." --inputbox "Enter the rule number to delete. Available rules for selected chain: $max_index" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ $exitstatus -eq 0 ]; then
            	iptables -D $selected_chain $rule_number
                if [ $? -eq 0 ]; then
                    whiptail --msgbox "Rule deleted: $rule_type $rule_number" 10 40
                    break  # Valid rule deleted, exit the loop
                else
                    # Rule does not exist
                    whiptail --msgbox "Rule does not exist. Please try again." 10 40
                fi
            else
                whiptail --msgbox "Operation canceled." 10 40
                break  # User cancelled the rule number input, exit the loop
            fi
    	done
}



block_all_ssh_connections() {
    iptables -A INPUT -p tcp --dport 22 -j DROP
    whiptail --msgbox "All SSH connections have been blocked successfully." 10 40
}


block_all_connection_from_ip() {
    while true; do
        ip_to_block=$(whiptail --title "Block IP Address" --inputbox "Enter the IP address to block:" 10 40 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ $exitstatus -eq 0 ]; then
	        validate_ip "$ip_to_block"
            ip_validation_status=$?
            if [ $ip_validation_status -eq 0 ]; then
                iptables -A INPUT -s $ip_to_block -j DROP
                whiptail --msgbox "Connections from $ip_to_block have been blocked." 10 40
                break  # Valid input, exit the loop
            else
                whiptail --msgbox "Invalid IP address. Please provide a valid IP address." 10 60
            fi
        else
            whiptail --msgbox "Operation canceled." 10 40
            break  # User canceled, exit the loop
        fi
    done
}



block_all_connection_from_ip_temporally() {
	while true; do
		while true; do
		    ip_to_block=$(whiptail --title "Block IP Address Temporarily" --inputbox "Enter the IP address to block:" 10 40 3>&1 1>&2 2>&3)
		    exitstatus=$?

		    if [ $exitstatus -eq 0 ]; then
				validate_ip "$ip_to_block"
		        ip_validation_status=$?
		        if [ $ip_validation_status -eq 0 ]; then
		        	break # Valid ip address, exit the loop
		        else {
		            whiptail --msgbox "Invalid IP address. Please provide a valid IP address." 10 60
		        }
		        fi
		    else {
		        whiptail --msgbox "Operation canceled." 10 40
		        return  # User canceled
		    }
		    fi
		done
		
		
		while true; do
			start_time=$(whiptail --title "Specify Start Time" --inputbox "Enter the start time (HH:MM):" 10 40 3>&1 1>&2 2>&3)
			exitstatus=$?
			if [ $exitstatus -eq 0 ]; then
				break
			else
			    whiptail --msgbox "Operation canceled." 10 40
				return  # User canceled
			fi
		done
		
		while true; do
			end_time=$(whiptail --title "Specify End Time" --inputbox "Enter the end time (HH:MM):" 10 40 3>&1 1>&2 2>&3)
			if [ $exitstatus -eq 0 ]; then
				break
			else
			    whiptail --msgbox "Operation canceled." 10 40
				return  # User canceled
			fi
		done
		
		# Validate the HH:MM format for start and end times
		if [[ $start_time =~ ^([01][0-9]|2[0-3]):[0-5][0-9] && $end_time =~ ^([01][0-9]|2[0-3]):[0-5][0-9] ]]; then
			# Add iptables rules to block the IP during the specified time range
			iptables -A INPUT -s $ip_to_block -m time --timestart $start_time --timestop $end_time -j DROP

			whiptail --msgbox "Connections from $ip_to_block are blocked from $start_time to $end_time." 10 60
			break  # Valid input, exit the loop
		else {
		    whiptail --msgbox "Invalid time format. Please provide times in HH:MM format." 10 60
		}
		fi
	done
}



limit_rate_connection() {
    while true; do
        ip_to_limit=$(whiptail --title "Limit Connection Rate" --inputbox "Enter the IP address to limit (in the format X.X.X.X):" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ $exitstatus -eq 0 ]; then
            validate_ip "$ip_to_limit"
            ip_validation_status=$?
            if [ $ip_validation_status -eq 0 ]; then
                hits=$(whiptail --title "Specify Hits" --inputbox "Enter the number of hits to limit:" 10 40 3>&1 1>&2 2>&3)
                seconds=$(whiptail --title "Specify Time Window (Seconds)" --inputbox "Enter the time window in seconds:" 10 40 3>&1 1>&2 2>&3)

                # Add iptables rule to limit the rate of connections from the IP address
                iptables -A INPUT -s $ip_to_limit -m recent --update --seconds $seconds --hitcount $hits --name LIMIT_CONN -j DROP

                whiptail --msgbox "Connection rate from $ip_to_limit limited to $hits hits in $seconds seconds." 10 60
                break  # Valid input, exit the loop
            else
                whiptail --msgbox "Invalid IP address. Please provide a valid IPv4 address.." 10 80
            fi
        else
            whiptail --msgbox "Operation canceled." 10 40
            break  # User canceled, exit the loop
        fi
    done
}



reset_iptables() {
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    whiptail --msgbox "Iptables have been reset to the default rules." 10 40
}




display_iptables() {
    iptables -L --line-numbers > /tmp/iptables_rules.txt 2>&1
    exitstatus=$?

    if [ $exitstatus -eq 0 ]; then
        chain=""
        rule_num=0

        while IFS= read -r line; do
            if [[ $line == "Chain "* ]]; then
                chain=${line#Chain }
                rule_num=0
            elif [[ $line =~ ^[0-9]+ ]]; then
                rule_num=$((rule_num + 1))
            fi
        done < /tmp/iptables_rules.txt

        whiptail --title "Iptables Rules" --textbox /tmp/iptables_rules.txt 20 100 --scrolltext
    else
        whiptail --title "Iptables Rules" --msgbox "Failed to fetch iptables rules. Please check your iptables configuration." 10 60
    fi

    rm -f /tmp/iptables_rules.txt
}


network_statistics(){

	input_rules=$(iptables -L INPUT --line-numbers | grep -E '^[[:space:]]*[0-9]')
	output_rules=$(iptables -L OUTPUT --line-numbers | grep -E '^[[:space:]]*[0-9]')

	if [[ -z "$input_rules" && -z "$output_rules" ]]; then
		message="No INPUT or OUTPUT rules found in the filter table.\nPlease add some rules to see the statistics"
		echo $message
		whiptail --msgbox "$message" 20 60
		return
	fi



	while true; do
		total_packets_in=$(iptables -L INPUT -v -x -n | tail -n 1 | awk '{print $1}')
		total_bytes_in=$(iptables -L INPUT -v -x -n | tail -n 1 | awk '{print $2}')
		total_packets_out=$(iptables -L OUTPUT -v -x -n | tail -n 1 | awk '{print $1}')
		total_bytes_out=$(iptables -L OUTPUT -v -x -n | tail -n 1 | awk '{print $2}')
		blocked_packets=$(iptables -L -v -x -n | grep DROP | awk '{print $1}' | tail -n 1)
		
		
		whiptail --title "Iptables Network Statistics" --yesno "
		Iptables Network Statistics:

		Total Incoming Packets: $total_packets_in
		Total Incoming Bytes: $total_bytes_in
		Total Outgoing Packets: $total_packets_out
		Total Outgoing Bytes: $total_bytes_out

		Blocked Packets: $blocked_packets

		Press 'Update Statistics' to update
		" 15 60 --yes-button "Update Statistics" --no-button "Exit"

		return_code=$?
		
		
		if [ $return_code -eq 0 ]; then
			continue
		else
			whiptail --msgbox "Operation canceled." 10 60
			return
		fi

	done

}

while true; do
    menu_choice=$(whiptail --title "Firewall Manager" --menu "Choose an action:" 15 60 7 \
        "1" "Append Rule" \
        "2" "Insert Rule at specific position" \
        "3" "Add Custom Rule" \
        "4" "Delete Rule" \
        "5" "Display Rules" \
        "6" "Block all ssh connections" \
        "7" "Block all connections from IP" \
        "8" "Block all connections from IP temporally" \
        "9" "Limit rate connection from IP" \
        "10" "Reset Firewall" \
        "11" "Network Statistics" \
        "12" "Exit" 3>&1 1>&2 2>&3)
    
    exitstatus=$?

    if [ $exitstatus -eq 0 ]; then
        case $menu_choice in
            1) add_iptable_rule append;;
            2) add_iptable_rule insert;;
            3) add_iptables_custom_rule ;;
            4) delete_iptables_rule ;;
            5) display_iptables ;;
            6) block_all_ssh_connections;;
            7) block_all_connection_from_ip;;
            8) block_all_connection_from_ip_temporally;;
            9) limit_rate_connection;;
            10) reset_iptables;;
            11) network_statistics;;
            12) exit ;;
        esac
    else
        if [ $exitstatus -eq 1 ]; then
            whiptail --msgbox "Action canceled. Returning to menu." 10 40
        elif [ $exitstatus -eq 255 ]; then
            exit 0
        fi
    fi
done