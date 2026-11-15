function __attachedvalue-test_should_offer_completions_for_flags_or_options -a expected_commands
    set -l non_repeating_flags_or_options $argv[2..]
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __attachedvalue-test_parse_tokens
    test "$commands" = "$expected_commands"; and return $non_repeating_flags_or_options_absent
end

function __attachedvalue-test_should_offer_completions_for_positional -a expected_commands positional_index_comparison expected_positional_index
    set -l non_repeating_flags_or_options
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __attachedvalue-test_parse_tokens
    test "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __attachedvalue-test_parse_tokens -S
    set -l unparsed_tokens (__attachedvalue-test_tokens -pc)
    switch $unparsed_tokens[1]
    case 'attachedvalue-test'
        __attachedvalue-test_parse_subcommand 1 'l/level=?' 'tags=?' 'format=?' 'D=?' 'I=' 'regular=' 'h/help'
        switch $unparsed_tokens[1]
        case 'help'
            __attachedvalue-test_parse_subcommand -r 1 
        end
    end
end

function __attachedvalue-test_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __attachedvalue-test_parse_subcommand -S -a positional_count
    argparse -s r -- $argv
    set -l option_specs $argv[2..]
    set -l is_repeating_positional $_flag_r
    set -el _flag_r
    set -a commands $unparsed_tokens[1]
    set positional_index 0
    while true
        set -e unparsed_tokens[1]
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
        set unparsed_tokens $argv
        set positional_index (math $positional_index + 1)
        for non_repeating_flag_or_option in $non_repeating_flags_or_options
            if set -ql "_flag_$(string replace -a - _ -- $non_repeating_flag_or_option)"
                set non_repeating_flags_or_options_absent 1
                break
            end
        end
        test (count $unparsed_tokens) -eq 0 -o \( -z "$is_repeating_positional" -a "$positional_index" -gt "$positional_count" \) && break
    end
end

function __attachedvalue-test_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __attachedvalue-test_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__attachedvalue-test_tokens -p)
    if test -z "$(__attachedvalue-test_tokens -t)"
        set -l index (count (__attachedvalue-test_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'attachedvalue-test' -f
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test" l level' -l 'level' -o 'l' -fka '\'DEBUG\' \'INFO\''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test"' -l 'tags' -fka ''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test" format' -l 'format' -fka ''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test"' -s 'D' -rfka ''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test" I' -s 'I' -rfka ''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test" regular' -l 'regular' -rfka ''
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_positional "attachedvalue-test" -eq 1' -F
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_flags_or_options "attachedvalue-test" h help' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'attachedvalue-test' -n '__attachedvalue-test_should_offer_completions_for_positional "attachedvalue-test" -eq 2' -fa 'help' -d 'Show subcommand help information.'