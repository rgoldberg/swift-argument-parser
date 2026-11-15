#compdef attachedvalue-test

__attachedvalue-test_complete() {
    local -ar non_empty_completions=("${@:#(|:*)}")
    local -ar empty_completions=("${(M)@:#(|:*)}")
    _describe -V '' non_empty_completions -- empty_completions -P $'\'\''
}

__attachedvalue-test_custom_complete() {
    local -a completions
    completions=("${(@f)"$("${command_name}" "${@}" "${command_line[@]}")"}")
    if [[ "${#completions[@]}" -gt 1 ]]; then
        __attachedvalue-test_complete "${completions[@]:0:-1}"
    fi
}

__attachedvalue-test_cursor_index_in_current_word() {
    if [[ -z "${QIPREFIX}${IPREFIX}${PREFIX}" ]]; then
        printf 0
    else
        printf %s "${#${(z)LBUFFER}[-1]}"
    fi
}

_attachedvalue-test() {
    emulate -RL zsh -G
    setopt extendedglob nullglob numericglobsort
    unsetopt aliases banghist

    local -xr SAP_SHELL=zsh
    local -x SAP_SHELL_VERSION
    SAP_SHELL_VERSION="$(builtin emulate zsh -c 'printf %s "${ZSH_VERSION}"')"
    local -r SAP_SHELL_VERSION

    local context state state_descr line
    local -A opt_args

    local -r command_name="${words[1]}"
    local -ar command_line=("${words[@]}")
    local -ir current_word_index="$((CURRENT - 1))"

    local -i ret=1
    local -ar ___level=('DEBUG' 'INFO')
    local -ar arg_specs=(
        '(--level -l)'{--level=-,-l=-}':level:{__attachedvalue-test_complete "${___level[@]}"}'
        '*--tags=-:tags:'
        '--format-::format:{compset -P "="}'
        '*-D-:D:'
        '-I+:I:'
        '--regular=:regular:'
        ':input:_files'
        '(-h --help)'{-h,--help}'[Show help information.]'
        '(-): :->command'
        '(-)*:: :->arg'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0
    case "${state}" in
    command)
        local -ar subcommands=(
            'help:Show subcommand help information.'
        )
        _describe -V subcommand subcommands && ret=0
        ;;
    arg)
        case "${words[1]}" in
        help)
            "_attachedvalue-test_${words[1]}" && ret=0
            ;;
        esac
        ;;
    esac

    return "${ret}"
}

_attachedvalue-test_help() {
    local -i ret=1
    local -ar arg_specs=(
        '*:subcommands:'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

if [[ "${funcstack[1]}" = _attachedvalue-test ]]; then
    _attachedvalue-test "${@}"
else
    compdef _attachedvalue-test attachedvalue-test
fi