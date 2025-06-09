#!/bin/bash
#
# Copyright (c) 2013-2025 <Huxley Barbee>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# For support, please see https://bitbucket.org/barbee/optio

# $Id: optio.sh,v 1.4 2014/03/13 18:29:40 barbee Exp $

# These are overriden by the configuration files.
declare DEFAULT_BANNER="=== OPTIO MENU ==="
declare DEFAULT_PROMPT="Please make a selection> "
declare DEFAULT_BACK="Back"
declare DEFAULT_CONF="optio.conf"
declare DEFAULT_STATE=".optio.state"
declare DEFAULT_CONTINUE="Please hit enter to continue."
declare -i DEFAULT_STATE_LIMIT=100
declare -i OPTIO_VERBOSE=0
declare DEFAULT_YES_UPPER='Y'
declare DEFAULT_YES_LOWER='y'
declare DEFAULT_NO_UPPER='N'
declare DEFAULT_NO_LOWER='n'

declare OPTIO_CONF
declare OPTIO_STATE

declare OPTIO_VERSION='1.21'

# The data structures. Using parallel array since
# bash 3 doesn't have associative arrays.

# A list of menu itesm.
# Each item is stored in the format:
#   <menu name>.<item name>
declare -a items

# A list of commands.
# Th index matches the index of items.
declare -a commands

declare scriptletLibrary

# We need to support spaces in our menu item names.
DEFAULT_IFS=$IFS
IFS=$'\t'

### API Function
# optioAskValue
#
# Asks the user the given question and places the response in the
# given variable. If there is a previous answer stored in $OPTIO_STATE,
# that will be provided as the default. If the response is blank, optio
# will ask the question again. 
# 
# Arguments:
#   1: String: The question to ask.
#   2: resultVar: The variable name in which to store the response.
function optioAskValue() {

    local question=$1
    local resultVar=$2
    local answer

    while test -z "$answer"
    do
        echo -n "$question "

        # ${! is an indirect reference to read a variable.
        if test -n "${!resultVar}";
        then
            echo -n "[${!resultVar}] "
        fi

        read answer

        if test -z "$answer" -a -n "${!resultVar}";
        then
            answer=${!resultVar}
        fi

    done

    # But there is no indirect reference to write a variable
    eval $resultVar="\"$answer\""
    echo "${resultVar}=\"${!resultVar}\"" >> $OPTIO_STATE

}

### API Function
# optioAskValue
#
# Asks the user the given yes or no question and places the response in the
# given variable. If there is a previous answer stored in $OPTIO_STATE,
# that will be provided as the default. If the response is enither 'y' nor 'n'
# (case insensitive), optio will ask the question again.
# 
# Arguments:
#   1: String: The question to ask.
#   2: resultVar: The variable name in which to store the response.
function optioAskYesNo() {
    local question=$1
    local resultVar=$2

    while test 1;
    do
        local index=0
        echo -n "$question "

        # ${! is an indirect reference to read a variable.
        if test -n "${!resultVar}";
        then
            if test ${!resultVar} -eq 1;
            then
                echo -n " [${OPTIO_YES_UPPER}/${OPTIO_NO_LOWER}] "
            elif test ${!resultVar} -eq 0;
            then
                echo -n " [${OPTIO_YES_LOWER}/${OPTIO_NO_UPPER}] "
            else
                echo -n " [${OPTIO_YES_LOWER}/${OPTIO_NO_LOWER}] "
            fi
            
        else
            echo -n " [${OPTIO_YES_LOWER}/${OPTIO_NO_LOWER}] "
        fi

        read answer

        if test -z "$answer" -a -n "${!resultVar}";
        then
            if test ${!resultVar} -eq 0;
            then
                answer=${OPTIO_NO_LOWER}
            else
                answer=${OPTIO_YES_LOWER}
            fi
        fi

        # ${blah-x} is our trick to deal with the possibility of
        # an unset variable.
        if test "${answer-x}" == "${OPTIO_YES_LOWER}" -o "${answer-x}" == "${OPTIO_YES_UPPER}";
        then
            # But there is no indirect reference to write a variable
            eval $resultVar=1
            echo "${resultVar}=1" >> $OPTIO_STATE
            return 0
        elif test "${answer-x}" == "${OPTIO_NO_LOWER}" -o "${answer-x}" == "${OPTIO_NO_UPPER}";
        then
            eval $resultVar=0
            echo "${resultVar}=0" >> $OPTIO_STATE
            return 0
        fi

    done
}

function usage() {
    echo "$0 [-h] [-d] [-v] [-V] [-c] [-z] [-s <state file>] [-f <config file>]"
    echo "    -h Prints help"
    echo "    -d Debug"
    echo "    -v Verbose"
    echo "    -c Control+C will kill all child processes rather than optio itself"
    echo "    -z Disable Control+Z"  
    echo "    -s Specifies which state file to use"
    echo "    -f Specifies which config file to use"
    echo "    -V Prints version information"

    die ""
}

### API Function
# optioHitContinue
#
# Display the contents of $OPTIO_CONTINUE and waits for the user to
# hit enter.
# 
# Arguments: None
function optioHitContinue() {
    echo ${OPTIO_CONTINUE}
    read
}

function parseArguments() {

    while getopts Vhvdczf:s: option;
    do
            case $option in
                # Dumps our data structures.
                h)
                    usage
                    ;;
                v)
                    OPTIO_VERBOSE=1
                    ;;
                d)
                    set -x
                    ;;
                s)
                    OPTIO_STATE=$OPTARG
                    ;;
                V)
                    echo "Optio Menu Framework version ${OPTIO_VERSION}."
                    read
                    ;;
                f)
                    OPTIO_CONF=$OPTARG
                    ;;
                # Disable Control+Z
                z)
                    trap '' SIGTSTP
                    ;;
                # Disable Control+C
                c)
                    trap killChildren 2
                    ;;
                \?)
                    echo "Invalid option: -$OPTARG"
                    ;;
            esac
    done

    # Make sure all our configuration variables are set.
    echo ${OPTIO_CONF:=$DEFAULT_CONF}
    echo ${OPTIO_STATE:=$DEFAULT_STATE}
    echo ${OPTIO_BANNER:=$DEFAULT_BANNER}
    echo ${OPTIO_PROMPT:=$DEFAULT_PROMPT}
    echo ${OPTIO_BACK:=$DEFAULT_BACK}
    echo ${OPTIO_CONTINUE:=$DEFAULT_CONTINUE}
    echo ${OPTIO_STATE_LIMIT:=$DEFAULT_STATE_LIMIT}
    echo ${OPTIO_YES_LOWER:=$DEFAULT_YES_LOWER}
    echo ${OPTIO_YES_UPPER:=$DEFAULT_YES_UPPER}
    echo ${OPTIO_NO_LOWER:=$DEFAULT_NO_UPPER}
    echo ${OPTIO_NO_UPPER:=$DEFAULT_NO_LOWER}

}

function die() {
    echo $1 >&2
    kill -9 $$
}

function item.getIndexByName() {

    local name
    local index=0

    if test -z "$1" -o -z "$2";
    then
        die "Missing menu or item name $1 ${2}."
    fi

    name="${1}.${2}"

    while test $index -lt ${#items[@]};
    do
        if test $name == ${items[$index]};
        then
            return $index
        fi
        index=$(( $index + 1 ))
    done

    die "Referencing an invalid menu or menu item '${name}'."

}

function item.new() {
    local menuName=$1
    local itemName=$2

    if test -z "$menuName" -o -z "$itemName";
    then
        die "Either menu or item name not specified."
    fi

    # Add the new menu item. The entry has the format:
    #   <menu name>.<item name>.
    items+=( "${menuName}.${itemName}" )

    # Add a placeholder for the commands.
    commands+=('')

    return 0
}

function endsWith() {
    local this=$1
    local with=$2
    local length=${#with}
    local start

    if test ${#this} -lt $length;
    then
        return 0
    fi

    start=$(( ${#this} - $length ))

    if test $start -lt 0;
    then
        return 0
    fi

    if test "${this:$start:$length}" == "$with";
    then
        return 1
    else
        return 0
    fi
}

function item.addCommand() {
    local menuName=$1
    shift
    local itemName=$1
    shift
    local command=$1
    local itemIndex

    if test -z "$command" -o -z "$itemName" -o -z "$menuName";
    then
        die "Either command '${command} or item name '$itemName} not specified."
    fi

    item.getIndexByName $menuName $itemName
    itemIndex=$?

    commands[$itemIndex]+="${command}"

    if test "${command:0:5}" != "menu:";
    then
        if test "${command:0:9}" != "optioExit";
        then
            commands[$itemIndex]+=$'\n'
        fi
    fi

}

function dump() {
    echo items ${#items[@]} "${items[@]}"
    echo command ${#commands[@]} "${commands[@]}"
}

function trim() {
    local var=$1

    # leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"

    # trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"

    echo -n "$var"
}

function readConfiguration() {

    local currentMenu
    local currentItem
    local index=0

    if test  ! -r $OPTIO_CONF ;
    then
        die "The configuration file '${OPTIO_CONF}' is not readable."
    fi

    declare -a lines

    # Read all the lines into an array first.
    while read line;
    do

        if test -z "$line";
        then
            continue
        fi

        line=$( trim $line )

        if test -z "$line";
        then
            continue
        elif test ${line:0:1} == '#';
        then
            continue
        fi

        lines[index]=$line
        index=$(( $index + 1 ))

    done < $OPTIO_CONF

    # Parse through the optio global variables first.
    # We know when to stop when we see '@@@'.
    index=0
    while test $index -lt ${#lines[@]};
    do
        local line=${lines[$index]}
        local end=0

        if test ${line:0:3} == '@@@';
        then
            end=1

        else
            eval $line
        fi

        index=$(( $index + 1 ))

        if test $end -eq 1;
        then
            break
        fi

    done

    # We are done with the global variabls.
    # Let's now parse our menu items.
    #
    # = means a menu name.
    # + means an item name.
    # Any non-comment line is a command that belongs to the
    # previous item.
    while test $index -lt ${#lines[@]};
    do
        local line=${lines[$index]}

        if test ${line:0:3} == '@@@';
        then
            break
        fi


        local first=${line:0:1}

        if test $first  == '=';
        then
            # Found a menu.
            currentMenu=$( trim ${line:1} )
        elif test $first == '+';
        then
            # Found an item.
            currentItem=$( trim ${line:1} )
            item.new "$currentMenu" "$currentItem"
        else

            # Must be a command.

            if test -z "$currentItem";
            then
                die "Found orphan command ${line}."
            fi

            item.addCommand "$currentMenu" "$currentItem" $line

        fi
                
        index=$(( $index + 1 ))
        
    done

    index=$(( $index + 1 ))

    while test $index -lt ${#lines[@]};
    do
        local line=${lines[$index]}

        scriptletLibrary+=$line
        scriptletLibrary+=$'\n'

        index=$(( $index + 1 ))
    done

}

# Bash does not have any way of passing arrays up an down the call stack.
# Bash will expand any array argument into a list of words, thus becoming
# n arguments, not one. Like Tcl, it is possible to pass the argument
# by name, and indirectly reference the array with ${!. However, unlike,
# Tcl, there is no upvar keyword to return an array.
#
# The following is a kludge of sort.
# Bash has a declare keyword. declare -p will dump the given variable.
# It could be used like typeof in JavaScript or getClass() in Java.
# However, it's more than that. You can, with string manipulation,
# tranform the dump into an actual declare, which may be evald by the
# caller.
#
# There are other methods of returning arrays, however, this one avoid
# issues with array members with spaces.
#
# Though I'm generally opposed to the "hey it's not the intent of the
# lanaguage design but it works" attitude, I don't see another way of
# handling this without resorting to global variables.
#
# This usage does trouble me, but not enough to keep me up at night.
# - May 16, 2013. jhb.
function returnArray() {
    local declareString
    declareString=$( declare -p $1 )
    local var=$2

    declareString=${declareString#declare\ -a\ *=}
    declareString="declare -a $var=$declareString"
    echo $declareString
}

function menu.getItems() {

    local menuName=$1
    local returnVar=$2
    local -a results
    local index=0

    # Plus one for the dot in menu.item.
    local length=$(( ${#menuName} + 1 ))

    while test $index -lt ${#items[@]};
    do

        # Here we're looking for any menu item with a prefix of
        # "<menu name>.".
        if test ${items[$index]:0:$length} == "${menuName}.";
        then
            results+=( "${items[$index]:$length}" )
        fi
        index=$(( $index + 1 ))
    done

    returnArray results $returnVar
}

function showMenu() {

    local menuName=$1
    local level=${2-0}
    local run=1

    eval "$( menu.getItems $menuName displayItems )"

    # If this is not the top level menu, add a menu item 
    # that allows the user to go back to the previous menu.
    if test $level -gt 0;
    then
        displayItems+=( "${OPTIO_BACK}" )
    fi

    PS3=${OPTIO_PROMPT}

    while test $run -gt 0;
    do

        if test $OPTIO_VERBOSE -eq 0;
        then
            clear
        fi

        source $OPTIO_STATE

        echo ${OPTIO_BANNER}
        echo ""

        select choice in "${displayItems[@]}"
        do
            local itemIndex
            local command

            if test -z "$choice";
            then
                continue
            elif test $choice == "${OPTIO_BACK}";
            then
                return 0
            fi

            item.getIndexByName $menuName $choice
            itemIndex=$?
            command=${commands[$itemIndex]}

            if test -z "$command";
            then
                die "No command configured for ${choice}."
            fi

            if test "$command" == "optioExit";
            then
                # User has requested to exit optio.
                run=0
            elif test "${command:0:5}" == "menu:";
            then
                # User has to requested to go to a submenu.
                showMenu ${command:5} $(( $level + 1 ))
            else
                # Run a command in a sub shell.
                ( source /dev/stdin <<< $scriptletLibrary; IFS=$DEFAULT_IFS eval $command )
            fi

            break

        done

    done

}

function killChildren() {
    killChildrenOf $$
}

function killChildrenOf() {
    local parentPid=$1

    count=`ps --ppid $parentPid | wc -l`

    count=`expr $count - 1`

    for childPid in `ps --ppid $parentPid | tail -${count} | awk '{print $1}'`
    do
        killChildrenOf $childPid
        kill -9 $childPid 2> /dev/null
    done
}

function cleanStateFile() {

    local -a lines
    local length=0
    local begin=0
    local index=0

    # Initialize the state file if we don't already have one.
    if test ! -r $OPTIO_STATE;
    then
        echo "" > $OPTIO_STATE
        return 0
    fi

    # Figure out how many lines there are.
    while read line;
    do

        lines[index]=$line
        index=$(( $index + 1 ))

    done < $OPTIO_STATE

    length=${#lines[@]}

    begin=$(( $length - ${OPTIO_STATE_LIMIT} ))

    # Number of lines < $OPTIO_STATE_LIMIT.
    # Bail.
    if test $begin -lt 0;
    then
        return 0
    fi

    echo "" > $OPTIO_STATE

    # Write only the last $OPTIO_STATE_LIMIT lines to the $OPTIO_STATE file.
    for (( index=$begin; $index < ${#lines[@]}; index++ ));
    do
        echo ${lines[$index]} >> $OPTIO_STATE
    done

}

parseArguments "$@"
readConfiguration
cleanStateFile
if test $OPTIO_VERBOSE -eq 1;
then
    dump
    read
fi
source $OPTIO_STATE
showMenu root
cleanStateFile
