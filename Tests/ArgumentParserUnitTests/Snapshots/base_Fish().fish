function __base-test_complete_repeating_flag -a expected_commands expected_flags description
    complete -c 'base-test' -n "__base-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
end

function __base-test_complete_non_repeating_flag -a expected_commands expected_flags description
    complete -c 'base-test' -n "__base-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
end

function __base-test_complete_repeating_option -a expected_commands expected_options
    __base-test_complete_repeating_flag $argv
    complete -c 'base-test' -n "__base-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[4..-1]
end

function __base-test_complete_non_repeating_option -a expected_commands expected_options
    __base-test_complete_non_repeating_flag $argv
    complete -c 'base-test' -n "__base-test_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[4..-1]
end

function __base-test_should_offer_completions_for_flags_or_option_values -a expected_commands expected_options option_check
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
    __base-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a "$non_repeating_flags_absent" -eq 0 && eval $option_check
end

function __base-test_should_offer_completions_for_positional -Sa expected_commands positional_index_comparison expected_positional_index is_repeating_positional
    set -l non_repeating_flags
    set -l non_repeating_flags_absent 0
    set -l positional_index 0
    set -l expected_options
    set -l option
    set -l commands
    __base-test_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a \( "$positional_index" "$positional_index_comparison" "$expected_positional_index" \)
end

function __base-test_parse_tokens -S
    set -l unparsed_tokens (__base-test_tokens -pc)
    switch $unparsed_tokens[1]
    case 'base-test'
        __base-test_parse_subcommand 2 'name=' 'kind=' 'other-kind=' 'path1=' 'path2=' 'path3=' 'one' 'two' 'custom-three' 'kind-counter' 'rep1=+' 'r/rep2=+' 'h/help' || return
        switch $unparsed_tokens[1]
        case 'sub-command'
            __base-test_parse_subcommand 0 'h/help' || return
        case 'escaped-command'
            __base-test_parse_subcommand 1 'o:n[e=' 'h/help' || return
        case 'help'
            __base-test_parse_subcommand -r 1  || return
        end
    end
end

function __base-test_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __base-test_parse_subcommand -Sa positional_count
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

function __base-test_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __base-test_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__base-test_tokens -p)
    if test -z "$(__base-test_tokens -t)"
        set -l index (count (__base-test_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'base-test' -f
__base-test_complete_non_repeating_option 'base-test' '--name' 'The user\'s name.' -fka ''
__base-test_complete_non_repeating_option 'base-test' '--kind' '' -fka 'one two custom-three'
__base-test_complete_non_repeating_option 'base-test' '--other-kind' '' -fka 'b1_fish b2_fish b3_fish'
__base-test_complete_non_repeating_option 'base-test' '--path1' '' -F
__base-test_complete_non_repeating_option 'base-test' '--path2' '' -F
__base-test_complete_non_repeating_option 'base-test' '--path3' '' -fka 'c1_fish c2_fish c3_fish'
__base-test_complete_non_repeating_flag 'base-test' '--one' ''
__base-test_complete_non_repeating_flag 'base-test' '--two' ''
__base-test_complete_non_repeating_flag 'base-test' '--custom-three' ''
__base-test_complete_repeating_flag 'base-test' '--kind-counter' ''
__base-test_complete_repeating_option 'base-test' '--rep1' '' -fka ''
__base-test_complete_repeating_option 'base-test' '-r --rep2' '' -fka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test" -eq 1' -fka '(__base-test_custom_completion ---completion -- positional@0 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test" -eq 2' -fka '(__base-test_custom_completion ---completion -- positional@1 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
__base-test_complete_non_repeating_flag 'base-test' '-h --help' 'Show help information.'
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test" -eq 3' -fa 'sub-command' -d ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test" -eq 3' -fa 'escaped-command' -d ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test" -eq 3' -fa 'help' -d 'Show subcommand help information.'
__base-test_complete_non_repeating_flag 'base-test sub-command' '-h --help' 'Show help information.'
__base-test_complete_non_repeating_option 'base-test escaped-command' '--o:n[e' 'Escaped chars: \'[]\\.' -fka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for_positional "base-test escaped-command" -eq 1' -fka '(__base-test_custom_completion ---completion escaped-command -- positional@0 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
__base-test_complete_non_repeating_flag 'base-test escaped-command' '-h --help' 'Show help information.'