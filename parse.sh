#!/bin/bash

# Ensure cleanup even when Ctrl-C'd
finish () {
    echo "Cleaning up" >&2
    rm input/*.txt
}
trap finish EXIT

# If the amount is after the percentage of the page width, it's a credit; otherwise it's a debit
PERCENTAGE_CREDIT=75

# Database name
DB_NAME=bourso

# Insert a new operation
# 1: date;type;valeur;location;description;amount
# 2: separator (here: ';')
# 3: credit or debit (will be used to put a - sign on debits)
# Returns: row ID
mysql_insert () {
    d=$(echo "$1" | awk -F$2 '{print $1}' | perl -lpe "s/'/''/gm")
    t=$(echo "$1" | awk -F$2 '{print $2}' | perl -lpe "s/'/''/gm")
    val=$(echo "$1" | awk -F$2 '{print $3}' | perl -lpe "s/'//gm" | perl -lpe 's#^ ?([0123]*\d)\D?([01]\d)\D?2?0?(\d\d)$#$1/$2/20$3#gm')
    loc=$(echo "$1" | awk -F$2 '{print $4}' | perl -lpe "s/'/''/gm")
    des=$(echo "$1" | awk -F$2 '{print $5}' | perl -lpe "s/'/''/gm")
    mnt=$(echo "$1" | awk -F$2 '{print $6}' | tr ',' '.')

    if [ "$3" == "debit" ]; then
        s="-"
    else
        s=""
    fi

    sql="INSERT INTO operations (op_date, op_type, op_date_valeur, op_location, op_description, op_value) 
        VALUES (STR_TO_DATE('$d', '%d/%m/%Y'), '$t', STR_TO_DATE('$val', '%d/%m/%Y'), '$loc', '$des', $s$mnt); select last_insert_id();"
    mysql $DB_NAME -sNe "$sql" || {
        echo "MySQL error occurred." >&2
        echo "   query $sql" >&2
        echo "   args: $@" >&2
        echo "-1"
        return 1
    }
}

# Update an operation
# 1: row ID
# 2: additionnal information
# Returns: nothing
mysql_update () {
    id=$1
    val=$(echo $2 | perl -lpe "s/'/''/gm")

    sql="UPDATE operations SET op_description = concat(ifnull(op_description, ''), '\n', '$val') where id = $id"

    mysql $DB_NAME -e "$sql" >&2 || {
        echo "MySQL error occurred" >&2
        echo "  query $sql" >&2
        echo "  args: $@" >&2
    }
}

# Parse every input file
for f in input/*.pdf; do
    # Convert pdf to text
    pdftotext -layout $f
    txt=$(echo "$f" | sed 's/pdf$/txt/g')

    # Guess file type
    if grep -qi 'Extrait de votre compte' $txt; then
        type="CC"
    elif grep -qi 'Relevé de Carte' $txt; then
        type="CB"
    else
        echo "Unknown type for file: $txt" >&2
        continue;
    fi

    # Read every line from file, sequentially
    echo "Starting to analyze $txt"
    lineLength=$(wc -L $txt | awk '{print $1}')
    section="HEADER"
    emptyLines=0
    rm .rowId 2>/dev/null
    rowId=0
    while read line;
    do
        # Ignore empty lines
        if [ "$(echo "$line" | perl -lpe 's/\s+//gm')" == "" ]; then
            # If there are too many empty lines after the table, consider we're in the footer
            emptyLines=$((emptyLines + 1))
            if [ "$section" == "TABLE" ] && [ $emptyLines -ge 2 ]; then
                section="FOOTER"
            fi
            continue
        fi
        emptyLines=0

        # State machine loop
        lineId=0
        case $section in
        "HEADER")
            lineId=0
            if grep -qi Libellé <<<"$line"; then
                section="TABLE"
            fi
            echo "ignore $section: $line"
            ;;

        "TABLE")
            if grep -Pq "^\s*\d+/\d+/\d+\s" <<<"$line"; then
                lineId=1
                # Parse type/amount/description/etc
                if [ $type == "CC" ]; then
                    op=$(echo "$line" \
                        | perl -lpe 's/^\s*(\d+\/\d+\/\d+)\s*(VIR ?S?E?P?A?|PRLV|Relevé\s+différé|(REM CHQ\.?)|CHQ\.?|(RETRAIT ?D?A?B?)|(\*?CION CB)|(\*?INT DEB)|(AVOIR)|(CREDIT CB)|(CARTE)|)\s+(.+)\s+(\d+\/\d+\/\d+)\s+([\d,\.]+)$/$1;$2;$11;;$10;$12/gm')
                else # CB
                    op=$(echo "$line" \
                        | perl -lpe 's/^\s*(\d+\/\d+\/\d+)\s+((PAIEMENT\s+CARTE)|AVOIR|(CION OP\.ETR))\s+(\d+)\s+((\S{2})|)\s+(.+)\s+([\d,\.]+)\s+([\d,\.]+)$/$1;$2;$5;$6;$8;$9/gm')
                fi

                # Remove unnecessary spaces
                op=$(echo "$op" | sed -e 's/\s\+/ /g' -e 's/ \?; \?/;/g')

                # Get the location of the amount within the line
                amount=$(echo "$op" | awk -F\; '{print $NF}')
                pos=$(echo "$line" | grep -bo "$amount" | awk -F: '{print $1}')

                # Checks whether it's credit/debit
                if [ $(echo "100 * $pos / $lineLength > $PERCENTAGE_CREDIT" | bc) -eq 1 ]; then
                    credeb="credit"
                else
                    credeb="debit"
                fi

                # Replace 1.250,00 into 1250,00
                op=$(echo "$op" | perl -lpe 's/(\d+)\.(\d+,\d+)/$1$2/gm')

                # Save operation
                rowId=$(mysql_insert "$op" ";" $credeb)

            # Ignored lines
            elif grep -Pqi 'SOLDE\s+AU' <<<"$line"; then
                echo "ignored: $line"
            elif grep -Pqi 'A\s+VOTRE\s+DEBIT' <<<"$line"; then
                echo "ignored: $line"

            # Append text line to previous operation
            else
                mysql_update $rowId "$(echo $line | perl -lpe 's/\s+/ /gm')"
            fi
            ;;

        "FOOTER")
            # Check if we switched to a 2nd (3rd, etc) page
            if grep -Pqi 'Extrait de votre compte' <<<"$line"; then
                section="HEADER"
            elif grep -Pqi 'Relevé de Carte' <<<"$line"; then
                section="HEADER"
            elif grep -Pqi 'Période' <<<"$line"; then
                section="HEADER"
            else
                echo "ignore $section line: $line"
            fi
            ;;

        *)
            echo "Unknown machine state: $section" >&2
            ;;
        esac
    done <$txt
done

