function __math_complete_repeating_flag -a expected_commands expected_flags description
    complete -c 'math' -n "__math_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
end

function __math_complete_non_repeating_flag -a expected_commands expected_flags description
    complete -c 'math' -n "__math_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_flags'" (test -n "$description" && printf '-d %s' $description) -fa "$expected_flags"
end

function __math_complete_repeating_option -a expected_commands expected_options
    __math_complete_repeating_flag $argv
    complete -c 'math' -n "__math_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[4..-1]
end

function __math_complete_non_repeating_option -a expected_commands expected_options
    __math_complete_non_repeating_flag $argv
    complete -c 'math' -n "__math_should_offer_completions_for_flags_or_option_values '$expected_commands' '$expected_options' 'contains -- \"\$option\" (string split -n \\' \\' -- \$expected_options)'" $argv[4..-1]
end

function __math_should_offer_completions_for_flags_or_option_values -a expected_commands expected_options option_check
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
    __math_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands" -a "$non_repeating_flags_absent" -eq 0 && eval $option_check
end

function __math_should_offer_completions_for_positional -a expected_commands expected_positional_index
    set -l non_repeating_flags
    set -l non_repeating_flags_absent 0
    set -l positional_index 0
    set -l expected_options
    set -l option
    set -l commands
    set -l positional_count 0
    set -l is_repeating false
    __math_parse_tokens
    test "$status" -eq 0 -a "$commands" = "$expected_commands"; or return 1
    if test "$is_repeating" = true -a "$expected_positional_index" -eq "$positional_count"
        test "$positional_index" -ge "$expected_positional_index"
    else
        test "$positional_index" -eq "$expected_positional_index"
    end
end

function __math_parse_tokens -S
    set -l unparsed_tokens (__math_tokens -pc)
    set -l unparsed_commands (string split -n ' ' -- $expected_commands)
    test "$unparsed_tokens[1]" = "$unparsed_commands[1]" || return
    set -e unparsed_commands[1]
    switch $unparsed_tokens[1]
    case 'math'
        __math_parse_subcommand 0 false 'version' 'h/help' || return
        test "$unparsed_tokens[1]" = "$unparsed_commands[1]" || return
        set -e unparsed_commands[1]
        switch $unparsed_tokens[1]
        case 'add'
            __math_parse_subcommand 1 true 'x/hex-output' 'version' 'h/help' || return
        case 'multiply'
            __math_parse_subcommand 1 true 'x/hex-output' 'version' 'h/help' || return
        case 'stats'
            __math_parse_subcommand 0 false 'version' 'h/help' || return
            test "$unparsed_tokens[1]" = "$unparsed_commands[1]" || return
            set -e unparsed_commands[1]
            switch $unparsed_tokens[1]
            case 'average'
                __math_parse_subcommand 1 true 'kind=' 'version' 'h/help' || return
            case 'stdev'
                __math_parse_subcommand 1 true 'version' 'h/help' || return
            case 'quantiles'
                __math_parse_subcommand 4 true 'file=' 'directory=' 'shell=' 'custom=' 'custom-deprecated=' 'version' 'h/help' || return
            end
        case 'help'
            __math_parse_subcommand 1 true 'version' || return
        end
    end
end

function __math_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __math_parse_subcommand -Sa expected_positional_count expected_is_repeating
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

function __math_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf %s\n $subdirs
end

function __math_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION
    set -l tokens (__math_tokens -p)
    if test -z "$(__math_tokens -t)"
        set -l index (count (__math_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'math' -f
__math_complete_non_repeating_flag 'math' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math' '-h --help' 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math" 1' -fa 'add' -d 'Print the sum of the values.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math" 1' -fa 'multiply' -d 'Print the product of the values.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math" 1' -fa 'stats' -d 'Calculate descriptive statistics.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math" 1' -fa 'help' -d 'Show subcommand help information.'
__math_complete_non_repeating_flag 'math add' '--hex-output -x' 'Use hexadecimal notation for the result.'
__math_complete_non_repeating_flag 'math add' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math add' '-h --help' 'Show help information.'
__math_complete_non_repeating_flag 'math multiply' '--hex-output -x' 'Use hexadecimal notation for the result.'
__math_complete_non_repeating_flag 'math multiply' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math multiply' '-h --help' 'Show help information.'
__math_complete_non_repeating_flag 'math stats' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math stats' '-h --help' 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats" 1' -fa 'average' -d 'Print the average of the values.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats" 1' -fa 'stdev' -d 'Print the standard deviation of the values.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats" 1' -fa 'quantiles' -d 'Print the quantiles of the values (TBD).'
__math_complete_non_repeating_option 'math stats average' '--kind' 'The kind of average to provide.' -fka 'mean median mode'
__math_complete_non_repeating_flag 'math stats average' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math stats average' '-h --help' 'Show help information.'
__math_complete_non_repeating_flag 'math stats stdev' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math stats stdev' '-h --help' 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats quantiles" 1' -fka 'alphabet alligator branch braggart'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats quantiles" 2' -fka '(__math_custom_completion ---completion stats quantiles -- positional@1 (count (__math_tokens -pc)) (__math_tokens -tC))'
complete -c 'math' -n '__math_should_offer_completions_for_positional "math stats quantiles" 3' -fka '(__math_custom_completion ---completion stats quantiles -- positional@2)'
__math_complete_non_repeating_option 'math stats quantiles' '--file' '' -fa '(set -l exts \'txt\' \'md\';for p in (string match -e -- \'*/\' (commandline -t);or printf \n)*.{$exts};printf %s\n $p;end;__fish_complete_directories (commandline -t) \'\')'
__math_complete_non_repeating_option 'math stats quantiles' '--directory' '' -fa '(__math_complete_directories)'
__math_complete_non_repeating_option 'math stats quantiles' '--shell' '' -fka '(head -100 \'/usr/share/dict/words\' | tail -50)'
__math_complete_non_repeating_option 'math stats quantiles' '--custom' '' -fka '(__math_custom_completion ---completion stats quantiles -- --custom (count (__math_tokens -pc)) (__math_tokens -tC))'
__math_complete_non_repeating_option 'math stats quantiles' '--custom-deprecated' '' -fka '(__math_custom_completion ---completion stats quantiles -- --custom-deprecated)'
__math_complete_non_repeating_flag 'math stats quantiles' '--version' 'Show the version.'
__math_complete_non_repeating_flag 'math stats quantiles' '-h --help' 'Show help information.'
__math_complete_non_repeating_flag 'math help' '--version' 'Show the version.'
