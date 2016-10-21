
function __log --description 'Logs to a file for debugging'
# Uncomment this line to enable debug logging:
#   echo -e $argv >> ~/.fspy
end

function __cut
   set -l str $argv[1]
   set -l pos $argv[2]
   echo (string sub -l $pos -- $str)
   echo (string sub -s (math 1+$pos) -- $str)
end

function __right
   set -l str $argv[1]
   set -l pos $argv[2]
   string sub -s (math 1+$pos) -- $str
end

function __substr --description 'Classic substr(str, start, end) with 0-based indexing, start inclusive, end exclusive'
   set -l str $argv[1]
   set -l start (math $argv[2] + 1)
   set -l len (math $argv[3] - $argv[2])
   string sub -s $start -l $len -- $str
end

function __ltrim_ifmatch --description 'Trims arg2 from the left of arg1, if they match, returns 1 otherwise'
   set -l ln (string length -- $argv[2])
   set -l left (string sub -l $ln -- $argv[1])
   if test $left = $argv[2]
      string sub -s (math $ln + 1) -- $argv[1]
   else
      return 1
   end
end

function __ltrim_unsafe --description 'Trims arg2 from the left of arg1, even if they not match'
   set -l ln (string length -- $argv[2])
   string sub -s (math $ln + 1) -- $argv[1]
end

function __rtrim_unsafe --description 'Trims arg2 from the right of arg1, even if they not match'
   set -l ln (string length -- $argv[1])
   set -l ln (math $ln - (string length -- $argv[2]))
   string sub -l $ln -- $argv[1]
end

function __rtrim_ifmatch --description 'Trims arg2 from the right of arg1, if they match, returns 1 otherwise'
   set -l ln (string length -- $argv[2])
   set -l start (math (string length -- $argv[1]) - $ln + 1)
   set -l right (string sub -s $start -- $argv[1])
   if test $right = $argv[2]
      string sub -s (math $start - 1) -- $argv[1]
   else
      return 1
   end
end

function __call_argcomplete

   __log "Call argcomplete:" $argv

   set -lx input $argv[1]
   set -lx COMP_POINT $argv[2]
   set -lx tokenStart $argv[3]

   set -lx COMP_LINE (string sub -l $COMP_POINT -- $input)
   set -lx words (string split ' ' -- (string sub -l $COMP_POINT -- $input))
   set -lx lastWord $words[-1]

   set -lx _ARGCOMPLETE_COMP_WORDBREAKS \n'"\'@><=;|&(:'
   set -lx _ARGCOMPLETE 1
   set -lx CMD $words[1]

   set -l rval (eval $CMD 8>&1 9>&2 1>/dev/null 2>/dev/null)
   __log "CloudSDK returned: '$rval'"
   if test $status -ne 0
      return
   end

   if test ! $rval
      if test (count $words) -gt 2 -a -n $lastWord
         # Fallback scenario 1: try to ignore the last word if it's not complete:
         set -l lastWordLen (string length -- $lastWord)
         set -l fallbackPos (math $COMP_POINT - $lastWordLen)
         __call_argcomplete $input $fallbackPos $tokenStart
      end
      if test (count $words) -gt 3 -a -z $lastWord
         # Fallback scenario 2: if last word is blank try ignore the prev word
         set -l prevWordLen (string length -- $words[-2])
         set -l fallbackPos (math $COMP_POINT - $prevWordLen - 1)
         __call_argcomplete $input $fallbackPos $tokenStart
         return
      end
   end

   set -l options (string split \n -- (string replace -a -r \v \n -- $rval))
   set -l pattern (__right $input $COMP_POINT)
   set -l drop (__substr $input $COMP_POINT $tokenStart)

   for opt in $options
      set -l ignored (__ltrim_ifmatch $opt $pattern)
      if test $status = 0
         set -l match (__ltrim_unsafe $opt $drop)
         set -l arg (string split -m 1 ' ' -- $match)[1]
         echo $arg
      end
   end
end

function __python_argcomplete

   __log '$>' (date)

   set -l token (commandline -t)
   set -l input (commandline -cp)
   set -l fullLine (commandline -p)
   set -l tokenStart (math (string length -- $input) - (string length -- $token))

   __call_argcomplete $input $tokenStart $tokenStart

end

complete -x -c gcloud -a '(__python_argcomplete)'
