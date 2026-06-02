function __defaultasflag-test_complete_flag -a expected_commands expected_flags description
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
end

function __defaultasflag-test_complete_option -a expected_commands expected_options
    __defaultasflag-test_complete_flag $argv
    complete -c 'defaultasflag-test' -n "__defaultasflag-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[4..-1]
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
    set -l positional_count 0
    set -l is_repeating false
    __defaultasflag-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a "$non_repeating_flags_absent" -eq 0 && eval $option_check
end

function __defaultasflag-test_should_offer_completions_for_positional -a expected_commands expected_positional_index
    set -l non_repeating_flags
    set -l non_repeating_flags_absent 0
    set -l positional_index 0
    set -l expected_options
    set -l option
    set -l commands
    set -l positional_count 0
    set -l is_repeating false
    __defaultasflag-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands"; or return 1
    if test "$is_repeating" = true -a "$expected_positional_index" -eq "$positional_count"
        test "$positional_index" -ge "$expected_positional_index"
    else
        test "$positional_index" -eq "$expected_positional_index"
    end
end

function __defaultasflag-test_parse_tokens -S
    set -l unparsed_tokens (__defaultasflag-test_tokens -pc)
    switch $unparsed_tokens[1]
    case 'defaultasflag-test'
        __defaultasflag-test_parse_subcommand 1 false 'bin-path=' 'count=' 'verbose=' 'log-level=' 'help' 'h/help' || return
        switch $unparsed_tokens[1]
        case 'help'
            __defaultasflag-test_parse_subcommand 1 true  || return
        end
    end
end

function __defaultasflag-test_tokens
    set -l fish_version (string split -m 2 -f 1,2 -- . "$FISH_VERSION")
    if test $fish_version[1] -gt 4; or test $fish_version[1] -eq 4 -a $fish_version[2] -ge 1
        set -f tokenize --tokenize-raw
    else
        set -f tokenize -t
    end

    eval "function __defaultasflag-test_tokens
        commandline \$argv | read $tokenize -la tokens
        printf %s\n \$tokens
    end"

    __defaultasflag-test_tokens $argv
end

function __defaultasflag-test_parse_subcommand -Sa expected_positional_count expected_is_repeating
    set -a commands $unparsed_tokens[1]
    set positional_index 0
    set positional_count $expected_positional_count
    set is_repeating $expected_is_repeating
    set -l option_specs $argv[3..]
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
        test (count $unparsed_tokens) -eq 0 -o \( "$is_repeating" != true -a "$positional_index" -gt "$positional_count" \) && return
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
__defaultasflag-test_complete_option 'defaultasflag-test' '--bin-path' '' -fa '(__defaultasflag-test_complete_directories)'
__defaultasflag-test_complete_option 'defaultasflag-test' '--count' '' -fka ''
__defaultasflag-test_complete_option 'defaultasflag-test' '--verbose' '' -fka ''
__defaultasflag-test_complete_option 'defaultasflag-test' '--log-level' '' -fka 'DEBUG INFO WARN ERROR'
__defaultasflag-test_complete_flag 'defaultasflag-test' '--help' ''
complete -c 'defaultasflag-test' -n '__defaultasflag-test_should_offer_completions_for_positional "defaultasflag-test" 1' -F
__defaultasflag-test_complete_flag 'defaultasflag-test' '-h --help' 'Show help information.'
complete -c 'defaultasflag-test' -n '__defaultasflag-test_should_offer_completions_for_positional "defaultasflag-test" 2' -fa 'help' -d 'Show subcommand help information.'