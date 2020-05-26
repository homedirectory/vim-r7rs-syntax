#!/usr/bin/env bash

set -euo pipefail

DATE="$(date +%Y-%m-%d)"
readonly DATE

TMPD="$(mktemp -d --suffix vimgauche)"
readonly TMPD
cleanup() { rm -rf "$TMPD"; }
trap cleanup ERR SIGTERM EXIT

readonly LIB="$TMPD/lib.awk"
cat > "$LIB" <<'EOF'
BEGIN {
    FS = "\t"
    OFS = "\t"
    ATAT[0] = "u8"
    ATAT[1] = "s8"
    ATAT[2] = "u16"
    ATAT[3] = "s16"
    ATAT[4] = "u32"
    ATAT[5] = "s32"
    ATAT[6] = "u64"
    ATAT[7] = "s64"
    ATAT[8] = "f16"
    ATAT[9] = "f32"
    ATAT[10] = "f64"
    ATAT[11] = "c32"
    ATAT[12] = "c64"
    ATAT[13] = "c128"
    HTML[0] = "a"
    HTML[1] = "abbr"
    HTML[2] = "acronym"
    HTML[3] = "address"
    HTML[4] = "area"
    HTML[5] = "b"
    HTML[6] = "base"
    HTML[7] = "bdo"
    HTML[8] = "big"
    HTML[9] = "blockquote"
    HTML[10] = "body"
    HTML[11] = "br"
    HTML[12] = "button"
    HTML[13] = "caption"
    HTML[14] = "cite"
    HTML[15] = "code"
    HTML[16] = "col"
    HTML[17] = "colgroup"
    HTML[18] = "dd"
    HTML[19] = "del"
    HTML[20] = "dfn"
    HTML[21] = "div"
    HTML[22] = "dl"
    HTML[23] = "dt"
    HTML[24] = "em"
    HTML[25] = "fieldset"
    HTML[26] = "form"
    HTML[27] = "frame"
    HTML[28] = "frameset"
    HTML[29] = "h1"
    HTML[30] = "h2"
    HTML[31] = "h3"
    HTML[32] = "h4"
    HTML[33] = "h5"
    HTML[34] = "h6"
    HTML[35] = "head"
    HTML[36] = "hr"
    HTML[37] = "html"
    HTML[38] = "i"
    HTML[39] = "iframe"
    HTML[40] = "img"
    HTML[41] = "input"
    HTML[42] = "ins"
    HTML[43] = "kbd"
    HTML[44] = "label"
    HTML[45] = "legend"
    HTML[46] = "li"
    HTML[47] = "link"
    HTML[48] = "map"
    HTML[49] = "meta"
    HTML[50] = "noframes"
    HTML[51] = "noscript"
    HTML[52] = "object"
    HTML[53] = "ol"
    HTML[54] = "optgroup"
    HTML[55] = "option"
    HTML[56] = "p"
    HTML[57] = "param"
    HTML[58] = "pre"
    HTML[59] = "q"
    HTML[60] = "samp"
    HTML[61] = "script"
    HTML[62] = "select"
    HTML[63] = "small"
    HTML[64] = "span"
    HTML[65] = "strong"
    HTML[66] = "style"
    HTML[67] = "sub"
    HTML[68] = "sup"
    HTML[69] = "table"
    HTML[70] = "tbody"
    HTML[71] = "td"
    HTML[72] = "textarea"
    HTML[73] = "tfoot"
    HTML[74] = "th"
    HTML[75] = "thead"
    HTML[76] = "title"
    HTML[77] = "tr"
    HTML[78] = "tt"
    HTML[79] = "ul"
    HTML[80] = "var"
}
function basename(path) {
    sub(".*/", "", path)
    return path
}
function unwrap(field,    m) {
    if (match(field, /^{\(\w+ (.+)\)}$/, m))
        return m[1]
    return field
}
function print_with_at_expanded(line,    i, _line) {
    switch (line) {
    case /@@/:
        for (i in ATAT) {
            _line = line
            gsub(/@@/, ATAT[i], _line)
            print _line
        }
        break
    case /html:@var{element}/:
        for (i in HTML) {
            _line = line
            gsub(/@var{element}/, HTML[i], _line)
            print _line
        }
        break
    default:
        print line
        break
    }
}
EOF

main() {
    if [[ -z "${GAUCHE_SRC+defined}" ]]; then
        echo "Please set GAUCHE_SRC to gauche source path" >&2
        exit 1
    fi

    if [[ -z "${VIM_SRC+defined}" ]]; then
        echo "Please set VIM_SRC to vim source path" >&2
        exit 1
    fi

    if [[ -z "${1+defined}" ]]; then
        usage
    fi

    local cmd
    case "$1" in
        ( tsv \
        | macro \
        | specialform \
        | function \
        | variable \
        | constant \
        | module \
        | class \
        | syntax \
        | ftplugin \
        )
            cmd="$1"
            shift
            build_"$cmd" "$@"
            ;;
        (*)
            usage
            ;;
    esac
}

usage() {
    cat >&2 <<EOF
Usage: $0 CMD [ARG...]

Commands:
    tsv
    macro
    specialform
    function
    variable
    constant
    module
    class
    syntax
    ftplugin
EOF
    exit 1
}

build_tsv() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 tsv [NAME...]

Convert Gauche document source files to a TSV table.

Args:
    NAME        name of texinfo source file, suffix (.texi) can be omitted
EOF
        exit 1
    fi

    local name files=()
    for name in "$@"; do
        files+=("$GAUCHE_SRC/doc/${name%.texi}.texi")
    done

    grep -E '^@def' "${files[@]}" \
        | sed 's/:/ /' \
        | gawk -i "$LIB" \
              'BEGIN { FS = " " }
               { $1 = basename($1)
                 # Join fields surrounded by {}
                 for (i = 3; i <= NF; i++) {
                     j = i
                     while ($i ~ /^{/ && $j !~ /}$/) {
                         j++
                         if (j > NF) break
                     }
                     if (j > i)
                         for (k = i + 1; k <= j; k++) {
                             $i = $i " " $k
                             $k = ""
                         }
                 }
                 print
               }' \
        | sed -E 's/\t{2,}/\t/g' \
        | gawk -i "$LIB" \
              '{ # $3 is either category in @def(fn|tp)x? (e.g. {Class}) or
                 # identifier in @def(mac|spec|fun)x? (e.g. let).
                 # Some identifiers are surrounded by {} (e.g. {(setter ...)}),
                 # having () inside.
                 if ($3 ~ /^{[^()]+}$/)
                     # $3 may have inconsistent cases; e.g. {Condition [tT]ype}
                     print $1, $2, tolower($3), unwrap($4)
                 else
                     print $1, $2, "", unwrap($3)
               }' \
        | sort | uniq
}

build_macro() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 macro FILE

Generate vim syntax for Gauche macros.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' '$2 ~ /^@defmacx?$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | find_undefined_keywords_in 'scheme\w*Syntax' \
        | gawk '{ switch ($0) {
                  case "use":
                      # skip it as it is handled in schemeImport
                      break
                  case "define-class":
                      # Can be defined only on toplevel
                      print "syn keyword schemeSpecialSyntax", $0
                      break
                  case "^c":
                      print "syn match schemeSyntax /\\^[_a-z]/"
                      break
                  default:
                      print "syn keyword schemeSyntax", $0
                      break
                  }
                }'
}

build_specialform() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 specialform FILE

Generate vim syntax for Gauche special forms.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' '$2 ~ /^@defspecx?$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | find_undefined_keywords_in 'scheme\w*Syntax' \
        | gawk '{ switch ($0) {
                  case "import":
                      # skip it as it is handled in schemeImport
                      break
                  case /^(require|define-(constant|in-module|inline))$/:
                      # Can be defined only on toplevel (except define-inline)
                      print "syn keyword schemeSpecialSyntax", $0
                      break
                  case /^((define|select)-module|export-all)$/:
                      print "syn keyword schemeLibrarySyntax", $0
                      break
                  default:
                      print "syn keyword schemeSyntax", $0
                      break
                  }
                }'
}

build_function() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 function FILE

Generate vim syntax for Gauche functions.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' \
        '$2 ~ /^@defunx?$/ ||
         ($2 ~ /^@def(fn|tp)x?$/ && $3 ~ /^{(generic )?function}$/) { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | find_undefined_keywords_in 'schemeFunction' \
        | gawk '{ print "syn keyword schemeFunction", $0 }'
}

build_variable() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 variable FILE

Generate vim syntax for Gauche variables.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' \
        '$2 ~ /^@defvarx?$/ ||
         ($2 ~ /^@defvrx?$/ && $3 ~ /^{comparator}$/) { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | gawk '{ print "syn keyword schemeVariable", $0 }'
}

build_constant() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 constant FILE

Generate vim syntax for Gauche constants.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' '$2 ~ /^@defvrx?$/ && $3 ~ /^{constant}$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | find_undefined_keywords_in 'schemeConstant' \
        | gawk '{ print "syn keyword schemeConstant", $0 }'
}

build_module() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 module FILE

Generate vim syntax for Gauche module names.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' \
        '$2 ~ /^@deftpx?$/ && $3 ~ /^{(builtin )?module}$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | gawk '{ print "syn keyword gaucheModule", $0 }'
}

build_class() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 class FILE

Generate vim syntax for Gauche classes.

Args:
    FILE        TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F '\t' \
        '$2 ~ /^@deftpx?$/ && $3 ~ /^{((meta|builtin )?class)}$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk -i "$LIB" '{ print_with_at_expanded($0) }' \
        | gawk '{ print "syn keyword gaucheClass", $0 }'
}

build_syntax() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 syntax PATH [FILE...]

Rebuild syntax/gauche.vim from generated vim files.

Args:
    PATH        path to syntax/gauche.vim
    FILE...     files generated by $0 (macro|specialform|...)
EOF
        exit 1
    fi

    local path="$1"
    shift

    local tmp="$TMPD/syntax.vim"
    {
        sed -n '1, /^" Keywords {{{1$/ p' "$path" | update_timestamp
        echo
        cat "$@" | sort | uniq
        echo
        sed -n '/^" Highlights {{{1$/, $ p' "$path"
    } > "$tmp"
    cp "$tmp" "$path"
}

build_ftplugin() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 ftplugin PATH [FILE...]

Rebuild ftplugin/gauche.vim from generated vim files.

Args:
    PATH        path to ftplugin/gauche.vim
    FILE...     files generated by $0 (macro|specialform|...)
EOF
        exit 1
    fi

    local path="$1"
    shift

    local tmp="$TMPD/ftplugin.vim"
    {
        sed -n '1, /^" lispwords {{{1$/ p' "$path" | update_timestamp
        echo
        gawk '{ print $4 }' "$@" \
            | gawk '/^(|r|g)let((|rec)(|1|\*)($|-)|\/)/ ||
                    /-let(|rec)(|1|\*)$/ ||
                    /^define($|-)/ ||
                    /-define$/ ||
                    /^match($|-)/ ||
                    /-match$/ ||
                    /^(|e)case($|-)/ ||
                    (/-(|e)case$/ && $0 !~ /(lower|upper|title)-case$/) ||
                    /^lambda($|-)/ ||
                    (/-lambda(|\*)$/ && $0 !~ /^scheme\.case-lambda$/) ||
                    /^set!($|-)/ ||
                    (/-set!$/ && $0 !~ /char-set!$/) ||
                    /^do(-|times|list)/' \
            | sort | uniq \
            | find_undefined_lispwords \
            | sed -E 's/(.*)/setl lispwords+=\1/'
    } > "$tmp"
    cp "$tmp" "$path"
}

update_timestamp() {
    sed -E 's/^(" Last Change:)[0-9]{4}-[0-9]{2}-[0-9]{2}$/\1'"$DATE/"
}

find_undefined_keywords_in() {
    local groupname="$1" keyword
    while read -r keyword; do
        if ! grep "^syn keyword $groupname $(esc "$keyword")$" \
               "$VIM_SRC"/runtime/syntax/scheme.vim > /dev/null 2>&1
        then
            echo "$keyword"
        fi
    done
}

find_undefined_lispwords() {
    local lispword
    while read -r lispword; do
        if ! grep "^setl lispwords+=$(esc "$lispword")$" \
               "$VIM_SRC"/runtime/ftplugin/scheme.vim > /dev/null 2>&1
        then
            echo "$lispword"
        fi
    done
}

# Escape meta characters in BASIC regular expressions
esc() {
    echo "$1" | sed -E 's@(\*|\.|\^|\$)@\\\1@g'
}

main "$@"
