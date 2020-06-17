#!/usr/bin/env bash

###############################################################################
# runTests.sh
#
# Usage: runTests.sh  [testFile]
#        where testFile defaults to testCases.in
#
# Processes a test file such as the testCases.in included with this package
###############################################################################

# Process one line from the test cases file. Invoked below through mapfile.
function _shellfloat_runTests()
{
    local lineNumber=$1
    local text=$2

    # Enable line continuation. Since this function is invoked with
    # the mapfile builtin, we cannot access global storage, so we use the disk.
    local COMMAND_BUFFER=/tmp/shellfloat.tmp

    # Trim leading whitespace
    [[ $text =~ ^[$' \t']*(.*) ]]
    text=${BASH_REMATCH[1]}

    # Skip comments and blank lines
    [[ "$text" =~ ^# || -z $text ]] && return 0

    # Check for line continuation
    local len="${#text}"
    if [[ ${text:$((len-1))} == '\' ]]; then

        # Eat the continuation character and add to the buffer
        echo -n "${text/%\\/ }" >> "$COMMAND_BUFFER"
        
        # Defer processing
        return

    # No line continuation
    else

        # Assemble the command
        local command
        if [[ -s "$COMMAND_BUFFER" ]]; then
            command="$(<$COMMAND_BUFFER)$text"
        else
            command=$text
        fi

        words=($command)

        # Expand first word to an assertion function
        case ${words[0]} in

            Code)
                words[0]=_shellfloat_assert_return${words[0]}

                # Validate next word as a positive integer
                if [[ ! "${words[1]}" =~ ^[0-9]+$ ]]; then
                    echo Line: $lineNumber: Command "$command"
                    echo FAIL: \"Code\" requires integer return code
                    return 1
                else
                    nextWord=2
                fi
                ;;

            String)
                words[0]=_shellfloat_assert_return${words[0]}
                # Allow multiword arguments if quoted
                if [[ ${words[1]} =~ ^\" ]]; then
                    if [[ ${words[1]} =~ \"$ ]]; then
                        nextWord=2
                    else
                        for ((nextWord=2;;nextWord++)); do
                            if [[ ${words[nextWord]} =~ \"$ ]]; then
                                ((nextWord++))
                                break
                            fi
                        done
                    fi
                else
                    nextWord=2
                fi
                ;;

            Both)
                ;;

            *)
                echo Line $lineNumber: Command "$command"
                echo FAIL: Code or String indicator required
                return 2
                ;;
        esac

        # Expand the next word to a shellfloat function name
        words[nextWord]=_shellfloat_${words[nextWord]}

        # Run the command, being respectful of shell metacharacters
        fullCommand="${words[@]}"
        eval $fullCommand
        echo $lineNumber: "$command"

        # Empty the command buffer
        : > "$COMMAND_BUFFER"
    fi

}


function _main()
{
    source shellfloat.sh
    source assert.sh
    
    # Process the test file line-by-line using the above runTests() function
    mapfile -t -c 1 -C _shellfloat_runTests < "${1:-testCases.in}"
    
    rm -f /tmp/shellfloat.tmp
    
    exit 0
}

_main "$@"

