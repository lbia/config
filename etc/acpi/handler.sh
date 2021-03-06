#!/bin/sh
# Default acpi script that takes an entry for all actions

# NOTE: This is a 2.6-centric script.  If you use 2.4.x, you'll have to
#       modify it to not use /sys

# $1 should be + or - to step up or down the brightness.
step_backlight() {
    for backlight in /sys/class/backlight/*/; do
        [ -d "$backlight" ] || continue
        max_brightness="$(cat "$backlight"/max_brightness)"
        step=$(( max_brightness / 20 ))
        # fallback if gradation is too low
        [ "$step" -gt "1" ] || step=1
        printf '%s' "$( ( $max_brightness "$1" $step ) )" >"$backlight/brightness"
    done
}

get_locker() {
    opt_dir="/var/opt"
    [ ! -d "$opt_dir" ] && mkdir -p "$opt_dir"
    locker_file="$opt_dir/locker"
    [ ! -f "$locker_file" ] && echo "swaylock" > "$locker_file"
    cat "$locker_file"
}

start_lock() {
    # make sure to fork in the background (&) otherwise pidof does not work
    locker="$(get_locker)"
    if [ "$locker" = "waylock" ]; then
        /usr/local/bin/waylock-env "sudoconf" >/dev/tty6 2>&1 &
    else
        /usr/local/bin/swaylock-env "sudoconf" >/dev/tty6 2>&1 &
    fi
}

kill_lock() {
    # if lock is running kill it
    # will be run again when opening lid
    locker="$(get_locker)"
    if [ "$locker" = "waylock" ]; then
        if pidof -x "waylock" -o $$ >/dev/null; then
            killall waylock
        fi
    else
        if pidof -x "swaylock" >/dev/null 2>&1; then
            killall swaylock
        fi
    fi
}

chech_lid_lock() {
    opt_dir="/var/opt"
    [ ! -d "$opt_dir" ] && mkdir -p "$opt_dir"
    lid_lock_file="$opt_dir/lid-lock"
    [ ! -f "$lid_lock_file" ] && echo "true" > "$lid_lock_file"
    lid_lock="$(cat "$lid_lock_file")"
    if [ "$lid_lock" = "false" ]; then
        return 1
    else
        return 0
    fi
}

minspeed=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
maxspeed=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
setspeed="/sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed"

case "$1" in
    button/power)
        # echo "Power Button pressed: $2" > /dev/tty6
        case "$2" in
            PBTN|PWRF)
                logger "Power Button pressed: $2"

                # shutdown the system
                # shutdown -P now

                start_lock
            ;;
            *)
                logger "ACPI action undefined: $2"
            ;;
        esac
    ;;
    button/sleep)
        # echo "Sleep Button pressed: $2" > /dev/tty6
        case "$2" in
            SBTN|SLPB)
                logger "Sleep Button pressed: $2"

                # suspend-to-ram
                # zzz

                start_lock
            ;;
            *)
                logger "ACPI action undefined: $2"
            ;;
        esac
    ;;
    ac_adapter)
        case "$2" in
            AC|ACAD|ADP0)
                case "$4" in
                    00000000)
                        echo "$minspeed" >"$setspeed"
                        # /etc/laptop-mode/laptop-mode start
                    ;;
                    00000001)
                        echo "$maxspeed" >"$setspeed"
                        # /etc/laptop-mode/laptop-mode stop
                    ;;
                esac
            ;;
            *)
                logger "ACPI action undefined: $2"
            ;;
        esac
    ;;
    battery)
        case "$2" in
            BAT0)
                case "$4" in
                    00000000)   # echo "offline" >/dev/tty6
                    ;;
                    00000001)   # echo "online"  >/dev/tty6
                    ;;
                esac
            ;;
            CPU0)
            ;;
            *)
                logger "ACPI action undefined: $2"
            ;;
        esac
    ;;
    button/lid)
        case "$3" in
            close)
                logger "LID closed"
                # echo "LID closed" > /dev/tty6

                # suspend-to-ram
                # zzz

                chech_lid_lock && kill_lock
            ;;
            open)
                logger "LID opened"
                # echo "LID opened" > /dev/tty6

                chech_lid_lock && start_lock
            ;;
            *)
                logger "ACPI action undefined (LID): $2"
            ;;
        esac
    ;;
    *)
        logger "ACPI group/action undefined: $1 / $2"
    ;;
esac
