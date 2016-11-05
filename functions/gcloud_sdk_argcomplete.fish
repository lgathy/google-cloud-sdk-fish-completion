
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
   set -lx prefix $argv[4]

   set -lx COMP_LINE (string sub -l $tokenStart -- $input)
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
         # Note: this can only happen in the first call on the stack, since we then fallback by words
         set -l trimmed (__rtrim_unsafe $input $lastWord)
         set -l fallbackPos (string length -- $trimmed)
         __call_argcomplete $input $fallbackPos $fallbackPos ''
      end
      if test (count $words) -gt 3 -a -z $lastWord
         # Fallback scenario 2: if last word is blank try fallback to the previous word
         set -l prevWordLen (string length -- $words[-2])
         set -l fallbackPos (math $COMP_POINT - $prevWordLen - 1)
         __call_argcomplete $input $fallbackPos $tokenStart ''
         return
      end
   end

   set -l options (string split \v -- $rval)
   set -l pattern (__substr $input $COMP_POINT $tokenStart)

   for opt in $options
      set opt (string replace -r '^(\w+)\\\\://' '$1://' -- $opt)
      set -l match (__ltrim_ifmatch $opt $pattern)
      if test $status -eq 0
         set -l args (string split -m 1 ' ' -- $match)
         if test (count $args) -gt 1
            echo -n "$prefix$args[1]"
            echo -n -e "\t"
            echo "$args[2]"
         else
            echo "$prefix$args[1]"
         end
      end
   end
end

function gcloud_sdk_argcomplete

   __log '$>' (date)

   set -l token (commandline -t)
   set -l input (commandline -cp)
   set -l fullLine (commandline -p)
   set -l cursorAt (string length -- $input)

   set -lx words (string split ' ' -- $input)

   set -lx prefix ''
   if string match -q -- '*@*' $words[-1]
      if string match -q -- '* ssh *' $input
         set -l parts (string split '@' $words[-1])
         set prefix "$parts[1]@"
         set words[-1] (string replace -- $prefix '' $words[-1])
         set cursorAt (math $cursorAt - (string length -- $prefix))
      end
   end
   if string match -q -- '--*=*' $words[-1]
      set -l parts (string split '=' -- $words[-1])
      set words[-1] (string join ' ' -- $parts)
      set prefix "$parts[1]="
   end
   set input (string join ' ' -- $words)
   # well, this is a bit strage, but seemingly 8 \-s will actually print 1 \, a bit of escaping hell
   set -l escaped (string replace -a -r '(\s\w+)://' '${1}\\\\\\\\://' -- $input)
   set -l ilen (string length -- $input)
   set -l elen (string length -- $escaped)
   if test $elen -gt $ilen
      set input $escaped
      set cursorAt (math $cursorAt - $ilen + $elen)
   end

   __call_argcomplete $input $cursorAt $cursorAt $prefix

end
