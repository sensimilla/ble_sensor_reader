#!/bin/bash

# workaround for bug in old version of hcitool
sudo /bin/hciconfig hci0 down
sudo /bin/hciconfig hci0 up

sudo /usr/bin/hcitool lewlclr
sudo /usr/bin/hcitool lewladd --random "FC:AF:FA:3A:F7:42"
sudo /usr/bin/hcitool lescan --whitelist --duplicates --passive 1>/dev/null &

packet=""

while IFS= read -r line
do
  # skip blank lines
  [[ $line == "" ]] && continue

  # skip hcidump initialisation output
  [[ $line =~ ^[0-9a-zA-Z] ]] && continue

  if [[ ${line:0:1} == ">" ]]; then
    # new packet, deal with the previous one

    packet=$(echo $packet | tr -d " ")

    # skip some malformed packets at start
    if [[ ${#packet} = 92 ]]; then

      # trim advert packet header
      packet=${packet:38}

      # echo "$packet"

      # get hex values
      battery=${packet:6:2}
      logging_interval=${packet:8:4}
      stored_logs=${packet:12:4}
      temp=${packet:16:4}
      humidity=${packet:20:4}
      dew_point=${packet:24:4}

      # do coversions
      battery=$((16#$battery))
      logging_interval=$((16#$logging_interval))
      stored_logs=$((16#$stored_logs))
      temp=$(awk "BEGIN {print $((16#$temp)) / 10}")
      humidity=$(awk "BEGIN {print $((16#$humidity)) / 10}")

      # TODO hex coversion for signed int negative values
      #dew_point=$(awk "BEGIN {print $((16#$dew_point)) / 100}")

      output_line_old=$output_line

      output_line="blue-maestro battery=${battery}i,temperature=$temp,humidity=$humidity"

      if [[ $output_line != $output_line_old ]]; then
        # add timestamp, influxdb says this is not required but counldn't get it to work.
        #write_line="$output_line $(date +%s%N)"
        echo $output_line
        echo -n $output_line >/dev/udp/influxdb/8089
      fi
    fi
    # store the first part of new packet
    packet="${line:2}"
  else
    # append extra lines to packet
    packet="$packet${line:2}"
  fi
done < <(sudo hcidump --raw)
