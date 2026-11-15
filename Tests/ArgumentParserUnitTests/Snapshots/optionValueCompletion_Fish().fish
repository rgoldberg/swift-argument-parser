function __optionvalue-test_should_offer_completions_for_flags_or_options -a expected_commands
    set -l non_repeating_flags_or_options $argv[2..]
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __optionvalue-test_parse_tokens
    test "$commands" = "$expected_commands"; and return $non_repeating_flags_or_options_absent
end

function __optionvalue-test_should_offer_completions_for_positional -a expected_commands positional_index_comparison expected_positional_index
    set -l non_repeating_flags_or_options
    set -l non_repeating_flags_or_options_absent 0
    set -l positional_index 0
    set -l commands
    __optionvalue-test_parse_tokens
    test "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __optionvalue-test_parse_tokens -S
    set -l unparsed_tokens (__optionvalue-test_tokens -pc)
    switch $unparsed_tokens[1]
    case 'optionvalue-test'
        __optionvalue-test_parse_subcommand 1 'level=' 't/tags=+' 'D=' 'format=' 'verbose' 'h/help'
        switch $unparsed_tokens[1]
        case 'help'
            __optionvalue-test_parse_subcommand -r 1 
        end
    end
end

function __optionvalue-test_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __optionvalue-test_parse_subcommand -S -a positional_count
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

function __optionvalue-test_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __optionvalue-test_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__optionvalue-test_tokens -p)
    if test -z "$(__optionvalue-test_tokens -t)"
        set -l index (count (__optionvalue-test_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'optionvalue-test' -f
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" level' -l 'level' -rfka '\'DEBUG\' \'INFO\''
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test"' -l 'tags' -s 't' -rfka '\'red\' \'green\''
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" D' -s 'D' -rfka '\'debug\' \'release\''
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" format' -l 'format' -rfka '\'json\' \'yaml\''
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" mode' -o 'mode' -rfka '\'fast\' \'slow\''
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" verbose' -l 'verbose'
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_positional "optionvalue-test" -eq 1' -F
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_flags_or_options "optionvalue-test" h help' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'optionvalue-test' -n '__optionvalue-test_should_offer_completions_for_positional "optionvalue-test" -eq 2' -fa 'help' -d 'Show subcommand help information.'