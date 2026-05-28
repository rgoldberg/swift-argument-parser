function __defaultasflag-test_complete_repeating_option -a expected_commands expected_options
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options'" $argv[3..-3] -fa "$expected_options"
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[-2..]
end

function __defaultasflag-test_complete_non_repeating_option -a expected_commands expected_options
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options'" $argv[3..-3] -fa "$expected_options"
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[-2..]
end

function __defaultasflag-test_should_offer_completions_for_flags_or_option_values -a expected_commands expected_options option_check
    set -l flags (string split -n ' ' -- $expected_options)
    if test -z "$option_check"
        set option_check true
        set non_repeating_flags _flag_(string replace -a - _ -- (string trim -lc - -- $flags))
    else
        set non_repeating_flags
    end
    set -l non_repeating_flags_absent 0
    set -l positional_index 0
    set -l option
    set -l commands
    __defaultasflag-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a "$non_repeating_flags_absent" -eq 0 && eval $option_check
end

function __defaultasflag-test_should_offer_completions_for_repeating_positional
    set -l is_repeating_positional 0
    __defaultasflag-test_should_offer_completions_for_positional $argv
end

function __defaultasflag-test_should_offer_completions_for_non_repeating_positional
    __defaultasflag-test_should_offer_completions_for_positional $argv
end

function __defaultasflag-test_should_offer_completions_for_positional -Sa expected_commands positional_index_comparison expected_positional_index
    set -l non_repeating_flags
    set -l non_repeating_flags_absent 0
    set -l positional_index 0
    set -l expected_options
    set -l option
    set -l commands
    __defaultasflag-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __defaultasflag-test_parse_tokens -S
    set -l unparsed_tokens (__defaultasflag-test_tokens -pc)
    switch $unparsed_tokens[1]
    case 'defaultasflag-test'
        __defaultasflag-test_parse_subcommand 1 'bin-path=' 'count=' 'verbose=' 'log-level=' 'help' 'h/help' || return
        switch $unparsed_tokens[1]
        case 'help'
            __defaultasflag-test_parse_subcommand -r 1  || return
        end
    end
end

function __defaultasflag-test_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __defaultasflag-test_parse_subcommand -S -a positional_count
    set -l option_specs $argv[2..]
    set -a commands $unparsed_tokens[1]
    set positional_index 0
    while true
        set -e unparsed_tokens[1]
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2>| read -l argparse_error
        if test -z "$argparse_error"
            set unparsed_tokens $argv
            set positional_index (math $positional_index + 1)
        else if string match -q '*: option requires an argument' -- $argparse_error
            set option "$unparsed_tokens[-1]"
            if not contains -- "$option" $flags
                return 1
            end
            set _flag_(string replace -a - _ -- (string trim -lc - -- $option)) $option
            argparse -sn "$commands" $option_specs -- $unparsed_tokens[..-2] || return
            set unparsed_tokens $argv
        else
            return 1
        end
        for non_repeating_flag in $non_repeating_flags
            if set -q -- "$non_repeating_flag"
                set non_repeating_flags_absent 1
                break
            end
        end
        test (count $unparsed_tokens) -eq 0 -o \( -z "$is_repeating_positional" -a "$positional_index" -gt "$positional_count" \) && return
    end
end

function __defaultasflag-test_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __defaultasflag-test_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__defaultasflag-test_tokens -p)
    if test -z "$(__defaultasflag-test_tokens -t)"
        set -l index (count (__defaultasflag-test_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'defaultasflag-test' -f
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '--bin-path' -fa '(__defaultasflag-test_complete_directories)'
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '--count' -fka ''
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '--verbose' -fka ''
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '--log-level' -fka 'DEBUG INFO WARN ERROR'
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '--help' 
complete -c 'defaultasflag-test' -n '__defaultasflag-test_should_offer_completions_for_non_repeating_positional "defaultasflag-test" -eq 1' -F
__defaultasflag-test_complete_non_repeating_option 'defaultasflag-test' '-h --help' -d 'Show help information.'
complete -c 'defaultasflag-test' -n '__defaultasflag-test_should_offer_completions_for_non_repeating_positional "defaultasflag-test" -eq 2' -fa 'help' -d 'Show subcommand help information.'