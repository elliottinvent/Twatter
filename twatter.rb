# We need the Twitter Gem
require 'twitter'
# YAML is used to read the settings file
require 'yaml'
# Logger writes log files
require 'logger'

class Numeric
  def percent_of(n,round_to=0)
    (self.to_f / n.to_f * 100.0).round(round_to)
  end
end

# This is what we use to shut down the script if it's interrupted
def shut_down
  puts "\nShutting down."
  close_logs
  exit
end

# We call this before we start checking handles
def connect_to_twitter
  @client = Twitter::REST::Client.new do |config|
    # These come from settings.yaml – you need to enter your details in there
    config.consumer_key        = @settings["twitter"]["consumer_key"]
    config.consumer_secret     = @settings["twitter"]["consumer_secret"]
    config.access_token        = @settings["twitter"]["access_token"]
    config.access_token_secret = @settings["twitter"]["access_token_secret"]
  end
end

def log(which,log_text)
  if which == "run" or which == "both"
    @run_log.info(log_text)
  end
  if which == "results" or which == "both"
    @results_log.info(log_text)
  end
end

# We use logging in this program and call this before it ends
def close_logs
  @run_log.close
  @results_log.close
end

# We call this function to check if a handle is available
def check_handle(handle)
  begin
    if handle.length < 5
      handle_error("!ts!","#{handle}")
      @twitter = false
    elsif handle.length > 15
      handle_error("!tl!","#{handle}")
      @twitter = false
    else
      @twitter = @client.user(handle)
    end
    if @twitter
      @taken_handles << handle
      @taken_count += 1
    else
      @invalid_handles << handle
      log_word = "Invalid"
    end
  rescue Exception => e
    if e.message == "User not found."
      @available_count += 1
      @available_handles << handle
      log_word = "Available"
    elsif e.message == "User has been suspended."
      @suspended_count += 1
      @suspended_handles << handle
      log_word = "Suspended"
    elsif e.message == "Rate limit exceeded"
      log_word = "Rate Limited"
      erorr = "RATE LIMIT EXCEEDED\nTwitter has stopped you checking any further user names for a little while. \nWhen this happens it's best to rerty again in 15 minutes or so. You were up to @#{handle}, you can restart your check from the same point by prefixing your pattern with #{handle}:"

      puts handle_error(erorr)
      @check_handles = false
    else
      log_word = "Error:"
      log("results",e.message)
      puts handle_error(e.message)
    end
    log("run",log_word + ": @#{handle}")
  end
end

# We print and log an error with this method
def handle_error(error_message, handle = "")
  # We call this error from two places, once when checking the pattern length
  # and again as we check each option.
  if handle == ""
    handle = "Your pattern"
  else
    handle = "@" + handle
  end
  if error_message == "!ts!"
    @invalid_count += 1

    error = "#{handle} is too short. Since 2015 new handles have to be > 4 chars."
  elsif error_message == "!tl!"
    @invalid_count += 1
    error = "#{handle} is too long. Maximum length is 15 characters (not inc @)."
  else
    line_length = error_message.length
    if line_length > 65
      line_length = 65
    end
    error = "="*line_length+"\n"
    error += "ERROR: " + error_message+"\n"
    error += "="*line_length+"\n"
    @unknown_errors += 1
    log('both',error)
    return "\n"+error
  end
end

# Send terminal to sleep
def go_to_sleep
  sleep_ms = @settings["sleep_ms"]
  if sleep_ms > 0
    sleep sleep_ms/1000
  else
    sleep 0
  end
end

def print_report(type)
  if type == "status" or type == "final_status"
    checked_counter = @checked_counter
    available_count = @available_count
    suspended_count = @suspended_count
    taken_count = @taken_count
    invalid_count = @invalid_count

    available_pc = (available_count).percent_of(@checked_counter)
    suspended_pc = (suspended_count).percent_of(@checked_counter)
    taken_pc = (taken_count).percent_of(@checked_counter)
    invalid_pc = (invalid_count).percent_of(@checked_counter)

    handle_report = "Available: #{available_count} (#{available_pc}%) Suspended: #{suspended_count} (#{suspended_pc}%) Taken: #{taken_count} (#{taken_pc}%)"
    if type == "status"
      handle_report = "\r" + handle_report + " Checking: @#{@possibility} (#{checked_counter}/#{@counter})"
      handle_report += "         "
    else
      log("results","\n\n#{handle_report}")
      log("run","\n\n#{handle_report}")
      handle_report = "\rChecked: #{checked_counter}/#{@counter} " + handle_report + " Invalid: #{invalid_count} (#{invalid_pc}%)         "
    end
  else
    if type == "t"
      type_label = "taken"
      handle_count = @taken_count
      handles = @taken_handles
    elsif type == "a"
      type_label = "available"
      handle_count = @available_count
      handles = @available_handles
    elsif type == "s"
      type_label = "suspended"
      handle_count = @suspended_count
      handles = @suspended_handles
    elsif type == "i"
      type_label = "invalid"
      handle_count = @invalid_count
      handles = @invalid_handles
    end
    handle_report = "List of #{type_label} handles:"
    if handle_count > 0
      handles.each do | handle |
        handle_report += "\n@"+handle
      end
    else
      handle_report += "\nNone."
    end
  end
  return handle_report
end

# Trap ^C and PID kill so we can close gracefully
Signal.trap("INT") { 
  shut_down 
}
Signal.trap("TERM") {
  shut_down
}

begin
  # Load the settings file
  @settings = YAML.load_file("settings.yaml")
rescue Exception=>e
  puts
  puts "You need to provide your Twitter API credentials in the settings.yml file."
  puts "An example file is provided – 'settings.EXAMPLE.yaml', enter your credentials "
  puts "in that file, rename it to settings.yaml and then run Twatter again."
  puts
  exit
end

begin
  # We delete the log that was created last time this program run
  File.delete("logs/last_run.log")
rescue Exception=>e
  # First time the program runs there isn't a log, it's no problem
end

# and create a new one:
@run_log = Logger.new('logs/last_run.log')

# Keep everything in the results log aging the logs according to the settings
@results_log = Logger.new('logs/results.log', @settings["keep_files"], @settings["max_size"])

if @settings["twitter"]["consumer_key"] == "YOUR_CONSUMER_KEY"
  puts
  puts "Please enter your Twitter Developer credentials in settings.yaml."
  puts "If you don't have Twitter Developer credentials you can register at "
  puts "https://dev.twitter.com/apps"
  shut_down
end

arg = ARGV[0]
ARGV.clear

if arg == "shush"
  shush = true
else
  shush = true
end
puts "="* 85

puts "To get started enter a pattern. Please use the following pattern rules:"
puts
puts "C = consonant"
puts "V = vowel"
puts "L = letter" 
puts "N = number"
puts "X = letter or number"
puts "U = underscore"
puts "A = letter, number or underscore (anything)"
puts "Lists: [comma,seperated,values] or [colours.txt]"
puts "Skip To: 'testeb:testVC' means that it'll start checking at 'testeb'"
puts "You can use a lowercase letter, a number or underscore for fixed characters"
puts
if !shush
  puts "For example, the pattern 'testVC' would check all possibilities of 'test' "
  puts "followed by every vowel combined with every consonant e.g. testab, testac, "
  puts "testad, testaf, testag and so on."
  puts
  puts "You can also use lists by enclosing comma seperated values in square brackets, "
  puts "for example a pattern of '[blue,red,green,yellow]clouds' will run a check for "
  puts "'blueclouds', 'redclouds', you get the idea. You can also load lists from the "
  puts "'lists' directory by enclosing the list name in square brackets, e.g. a pattern of: "
  puts "'[colours]clouds' will run through all of the colours in clouds.txt. "
  puts
  puts "You can skip all these instructions by running the script with this argument: "
  puts "> ruby twatter.rb shush"
  puts
end
puts "Please enter your pattern:"

pattern = gets.strip

if pattern.include? ":"
  # User wants to skip to a certain option
  skip_to = pattern.split(":")[0]
  pattern = pattern.split(":")[1]
end

# Check pattern and set arrays
rules = pattern.split("")
pattern_array = Hash.new

# We start with this set to false and if we find an opening left brace
# we set it to true, load the list and skip that part of the pattern
# then set it to true false again once we reach the end of the list
list_declaration = false
# We set this if a lsit is defined
list_was_declared = false
# This counter keeps track of the minimum pattern length so we can
# let the user know if it's too short or too long
pattern_length = 0
# This is set to false if there's a problem processing the pattern
go_ahead = true

# These counters are used in the log and for console output
@available_count = 0
@suspended_count = 0
@taken_count = 0
@invalid_count = 0
@unknown_errors = 0

@available_handles = []
@suspended_handles = []
@taken_handles = []
@invalid_handles = []

# Set built in lists
letter_list = "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z"
vowel_list = "a,e,i,o,u"
consonant_list = "b,c,d,f,g,h,j,k,l,m,n,p,q,r,s,t,v,w,x,y,z"
number_list = "0,1,2,3,4,5,6,7,8,9"

# Create arrays out of lists
letters = letter_list.split(",")
vowels = vowel_list.split(",")
consonants = consonant_list.split(",")
numbers = number_list.split(",")
underscore = ["_"]

letters_and_numbers = letters + numbers
any = letters_and_numbers + underscore

rules.each_with_index do | rule, counter |
  if rule == "]"
    # If a list was previously found, we've reached the end of that list 
    # and can now interpret pattern characters as normal
    list_declaration = false
  elsif !list_declaration
    if rule == "["
      # A list has been defined (this is not be reset)
      list_was_declared = true
      # set list declation to true (this can be reset)
      list_declaration = true
      # Find where the list ends
      closing_brace = pattern.index(']',counter)
      # Get the list data
      list_data = pattern[counter+1..(closing_brace-1)]
      list_name_length = list_data.length+2

      loaded_list = []
      if list_data.include?(",")
        # This is a list of csv values – split them on comma
        list_items = list_data.split(",")
        list_items.each do |item|
          # add each item to the array
          loaded_list << item.strip
        end
      else
        # This is a file list, it must be present in the 'lists' folder
        puts 
        list_name = list_data
        if list_name.length >=4
          # If it's more than 4 chars then it might have already have an extension
          if list_name[-4,4] != ".txt"
            # If it doens't have an extension add one
            list_name += ".txt"
          end
        else
          # The list name is only 4 chars long so can't have an extension, add it 
          list_name += ".txt"
        end

        begin # There could be a problem opening the file
          File.open("lists/"+list_name, "r") do |list|
            # Open the file
            list.each_line do |item|
              # Build up the array from the items in the list
              loaded_list << item.strip
            end
          end
        rescue Exception=>e #if there's a problem then catch the error
          puts "File error: '#{e.message}"
          shut_down
        else
          # Tell the user that we've successfully loaded the list
          puts "List '" + list_name + "' loaded."
        end
      end
      pattern_array[counter] = loaded_list
    else
      if /^[a-z0-9_(C|V|L|N|X|U|A)]{1}$/.match?rule
        if rule == "C"
          # Consontant
          pattern_length += 1
          pattern_array[counter] = consonants
        elsif rule == "V"
          # Vowel
          pattern_length += 1
          pattern_array[counter] = vowels
        elsif rule == "L"
          # Letter
          pattern_length += 1
          pattern_array[counter] = letters
        elsif rule == "N"
          # Number
          pattern_length += 1
          pattern_array[counter] = numbers
        elsif rule == "X"
          # Letter or Number
          pattern_length += 1
          pattern_array[counter] = letters_and_numbers
        elsif rule == "U"
          # Underscore
          pattern_length += 1
          pattern_array[counter] = underscore
        elsif rule == "A"
          # Any valid char (letter, number or underscore)
          pattern_length += 1
          pattern_array[counter] = any
        else
          # This is just a normal character
          pattern_length += 1
          pattern_array[counter] = [ rule ]
        end
      else
        puts
        puts "Your pattern was invalid, valid Twitter characters are a-z, 0-9 and underscore ( _ )."
        puts "Uppercase letters are reserved for the pattern matching rules."
        shut_down
      end
    end
  end
end

# We now have a hash table containing one or more arrays
# that include all of the characters we want to combine

# No we creeate an array to include all of the possibilities
# we want to check
possibilities = [""]

# If the pattern is less than 5 characters or more than 15 we print an
# error. If they've provided a list we run these length checks per handle
if (pattern_length > 4 and pattern_length <= 15) or list_was_declared
  pattern_array.each do | key, character_array |
    # Loop through the array containing all of our patterns

    # We clear the 'possible handles' array each time we loop
    # otherwise if the pattern was testVC the possible handles
    # list would include testa (testV) instead of testab(testVC)
    # We couild make this toggleable so that if the user enters
    # the string testVC it'll check 't', 'te', 'tes', 'test', 
    # 'testa', 'testab' but this doesn't match the true pattern.
    possible_handles = []
    @counter = 0
    # The possibilities list is added to on each loop, building up
    possibilities.each do | possibility |
      character_array.each do | character |
        @counter += 1
        possible_handle = possibility + character
        possible_handles << possible_handle
      end
    end
    possibilities = possible_handles
  end

  if !shush
    puts
    if !skip_to
      puts "There are #{@counter} possibilities in total. Would you like to start checking?"
    else
      puts "There are #{@counter} possibilities in total but we'll skip to @#{skip_to} as requested."
      puts "Would you like to start checking?"
    end
    puts "Input y/yes to go ahead or anything else to cancel:"
  else
    if !skip_to
      puts "Check #{@counter} possible handles? (y/n)"
    else
      puts "Check #{@counter} possible handles? We'll skip to @#{skip_to} as requested. (y/n):"
    end
  end

  answer = gets.strip!
  puts

  # If a skip_to value has been set we set this to true once we've reached that possibility
  skipped = false
  skipped_counter = 0

  if !skip_to
    # TODD, add last_run.log and clear at start of every run
    puts "Results are updated in real time, percentages shown are percentages of checked handles."
    puts "If the program fails for any reason, you can see all results in 'last_run.log'."
  end

  if answer == "yes" or answer == "y"
    # Connect to Twitter by running this method
    connect_to_twitter

    @checked_counter = 0

    @check_handles = true
    possibilities.each do | possibility |
      if skip_to and !skipped
        skipped_counter += 1
        if possibility == skip_to
          skipped = true
          puts "#{skipped_counter} possibilities skipped."
          @counter = (@counter-skipped_counter)
        end
      else
        @possibility = possibility
        # @check_handles can get set to null if the connection to Twitter is blocked
        @checked_counter += 1
        check_handle(possibility)

        report = print_report("status")
        # We print empty space to make sure it covers the last string we checked
        STDOUT.write report

        go_to_sleep

        # If the user has been blocked then stop checking and proceed to report 
        break if !@check_handles
      end
    end

    report = print_report("final_status")
    # We print empty space to make sure it covers the last string we checked
    STDOUT.write report

    puts
    if @available_count > 0
      available_handle_report = print_report("a")
      puts available_handle_report
    else
      puts "\nNo available handles were found."
    end
    puts
    if @invalid_count > 0
      available_handle_report = print_report("i")
      puts available_handle_report
    end    
  end

  log("both",print_report("t")+"\n"+print_report("t")+"\n"+print_report("s")+"\n"+print_report("i"))

  puts "\nAll results are in log.txt. Would you like to see a list of the "
  puts "taken (t), suspended (s) and invalid (i) handles on-screen now? "
  puts 
  puts "You can input 't', 's', 'i', or 'all' to see them all. Input anything else to quit:"

  answer = gets.strip!
  puts

  if answer == "t"
    puts print_report("t")
  elsif answer == "s"
    puts print_report("s")
  elsif answer == "i"
    puts print_report("i")
  elsif answer == "all"
    puts print_report("t")
    puts
    puts print_report("s")
    puts
    puts print_report("i")
  end
else
  if pattern_length <= 4
    puts handle_error("!ts!")
  elsif pattern_length >= 15
    puts handle_error("!tl!")
  end
end

close_logs