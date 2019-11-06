#! /usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

last=${@:$#} # last parameter 
other=${*%${!#}} # all parameters except the last
exercises=`echo $last|sed 's/.tex$/e.tex/'`
solutions=`echo $last|sed 's/.tex$/s.tex/'`

ruby $DIR/build-worksheet.rb $other $last --output $exercises && pdflatex $exercises && pdflatex $exercises

ruby $DIR/build-worksheet.rb $other $last --solutions --output $solutions && pdflatex $solutions && pdflatex $solutions
