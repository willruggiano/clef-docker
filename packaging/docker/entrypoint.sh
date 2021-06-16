#!/bin/bash

init() {
    parse_json() { echo $1|sed -e 's/[{}]/''/g'|sed -e 's/", "/'\",\"'/g'|sed -e 's/" ,"/'\",\"'/g'|sed -e 's/" , "/'\",\"'/g'|sed -e 's/","/'\"---SEPERATOR---\"'/g'|awk -F=':' -v RS='---SEPERATOR---' "\$1~/\"$2\"/ {print}"|sed -e "s/\"$2\"://"|tr -d "\n\t"|sed -e 's/\\"/"/g'|sed -e 's/\\\\/\\/g'|sed -e 's/^[ \t]*//g'|sed -e 's/^"//' -e 's/"$//' ; }
    if [ ! -f "$DATA"/password ]; then
        < /dev/urandom tr -dc _A-Z-a-z-0-9 2> /dev/null | head -c32 > "$DATA"/password
    fi
    SECRET=$(cat "$DATA"/password)
    clef --configdir "$DATA" --stdio-ui --suppress-bootwarn init >/dev/null 2>&1 << EOF
$SECRET
$SECRET
EOF
    if [ "$(ls -A "$DATA"/keystore 2> /dev/null)" = "" ]; then
        clef --keystore "$DATA"/keystore --stdio-ui newaccount --lightkdf >/dev/null 2>&1 << EOF
$SECRET
EOF
    fi
    clef --keystore "$DATA"/keystore --configdir "$DATA" --stdio-ui setpw 0x"$(parse_json "$(cat "$DATA"/keystore/*)" address)" >/dev/null 2>&1 << EOF
$SECRET
$SECRET
$SECRET
EOF
    clef --keystore "$DATA"/keystore --configdir "$DATA" --stdio-ui attest "$(sha256sum /app/config/rules.js | cut -d' ' -f1 | tr -d '\n')" >/dev/null 2>&1 << EOF
$SECRET
EOF
}

run() {
    SECRET=$(cat "$DATA"/password)
    rm -f /tmp/stdin /tmp/stdout || true
    mkfifo /tmp/stdin /tmp/stdout
    (
    exec 3>/tmp/stdin
    while read < /tmp/stdout
    do
        if [[ "$REPLY" =~ "enter the password" ]]; then
            echo '{ "jsonrpc": "2.0", "id":1, "result": { "text":"'"$SECRET"'" } }' > /tmp/stdin
            break
        fi
    done
    ) &
    clef --stdio-ui --suppress-bootwarn --keystore "$DATA"/keystore --configdir "$DATA" --chainid "$CHAINID" --rules /app/config/rules.js --nousb --lightkdf --4bytedb-custom /app/config/4byte.json --pcscdpath "" --auditlog "" --loglevel 3 < /tmp/stdin | tee /tmp/stdout
}

full() {
    if [ ! -f "$DATA"/masterseed.json ]; then
        init
    fi
    run
}

# Global variables
ACTION="${CLEF_ACTION:-full}"
CHAINID="${CLEF_CHAINID:-5}"
DATA=/app/data
DRYRUN=0

for a in "$@"; do
    case "$a" in
        --run)
            ACTION="run"; shift ;;
        --init)
            ACTION="init"; shift ;;
        --full)
            ACTION="full"; shift ;;
        --chainid)
            shift; CHAINID="$1"; shift ;;
        --dryrun)
            DRYRUN=1; shift ;;
    esac
done

if [[ $DRYRUN -eq 1 ]]; then
    echo "Would run: $ACTION with --chainid $CHAINID"
    exit 0
fi

$ACTION
