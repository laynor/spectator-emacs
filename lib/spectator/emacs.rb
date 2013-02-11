require 'spectator/emacs/version'
require 'spectator'
require 'socket'
require 'open4'

class Object
  # Returns a string representing the object as a lisp sexp.
  def to_lisp
    to_s
  end
end

class Symbol
  # Returns a string that represents the symbol as a lisp
  # symbol. Underscores are converted to dashes.
  #
  # Example:
  #
  # ```
  # :foo_bar.to_lisp => 'foo-bar'
  # ```
  def to_lisp
    to_s.gsub "_", "-"
  end

  # Returns a symbol with the same name prefixed by a colon. This is
  # convenient when converting a symbol with the {#to_lisp} method.
  #
  # Example:
  #
  # ```
  # :foo_bar.keyword.to_lisp => ':foo-bar'
  # ```
  def keyword
    if self[0] == ':'
      self
    else
      ":#{to_s}".to_sym
    end
  end
end

class String
  # Returns a string that represents a lisp string.
  # This is basically just an alias for {String#inspect}
  def to_lisp
    inspect
  end
end

class Array
  # Returns a string that represents the array as a lisp list.
  #
  # Example:
  #
  # ```
  # [:foo, 123, "bar"].to_lisp => '(foo 123 "bar")'
  def to_lisp
    sexp_array = map { |el| el.to_lisp }
    "(#{sexp_array.join ' '})"
  end
end

class Hash
  # Creates and returns a new hash tabke with the same keys and values
  # and tags it to be rendered as an association list by the to_lisp
  # method.
  #
  # For example, ```{:a => :b, :x => 1}``` would be rendered as
  #
  # ```
  #   ((a . b) (x . 1))
  # ```
  def as_alist
    merge(:__render_as => :alist)
  end

  # Creates and returns a new hash tabke with the same keys and values
  # but tagged to be rendered as a flat list by the to_lisp method.
  #
  # For example, ```{:a => :b, :x => 1}``` would be rendered as
  #
  # ```
  #   (a b x 1)
  # ```
  def as_flat_list
    merge(:__render_as => :flat )
  end

  # Creates and returns a new hash table with the same keys and values
  # but tagged to be rendered as a property list by the to_lisp method.
  # The keys must be symbols, and they will be rendered as keywords.
  #
  # For example, ```{:a => :b, :x => 1}``` would be rendered as
  #
  # ```
  #   (:a b :x 1)
  # ```
  def as_plist
    merge(:__render_as => :plist)
  end

  # Returns a symbol indicating how the hash will be rendered by the
  # to_lisp method. The possible values are :flat, :alist, :plist.
  def rendering_type
    self[:__render_as] or :plist
  end

  # Renders the hash as a list, depending on how it has been tagged.
  # If the hash has not been tagged, it will be rendered as a property
  # list, see as_plist.
  def to_lisp
    def pjoin(string_list)
      "(#{string_list.join ' '})"
    end
    h = self.clone
    h.delete(:__render_as)
    case rendering_type
    when :alist
      pjoin(h.map { |k, v| "(#{k.to_lisp} . #{v.to_lisp})" })
    when :flat
      pjoin(h.map { |k, v| "#{k.to_lisp} #{v.to_lisp}" })
    when :plist
      pjoin(h.map { |k, v| "#{k.keyword.to_lisp} #{v.to_lisp}" })
    end
  end
end


module Spectator
  # This exception is thrown when an error occurs when trying to
  # extract the rspec result summary (number of examples ran, number
  # of failures, number of pending examples) from its output.
  class SummaryExtractionError < RuntimeError
  end

  module Specs
    # Summarizes the rspec results as one of `:failure, :pending, :success`.
    #
    # @param [Hash] rspec_stats A Hash table with keys ```:examples, :failures, :pending, :summary, :status```.
    #    See {#extract_rspec_summary} for details about the meaning of the key/value pairs in this table.
    def rspec_status(rspec_stats)
      if rspec_stats[:failures] > 0
        :failure
      elsif rspec_stats[:pending] > 0
        :pending
      else
        :success
      end
    end

    # Returns a hash that summarizes the rspec results.
    #
    # @param [String] output the rspec output
    # @param [Integer] line_number the line number of the summary in the rspec
    #   output. It can be negative: -1 indicates the last line, -2
    #   indicates the second last line and so on.
    # @return [Hash] a hash table with keys ```:examples, :failures, :pending, :summary, :status```.
    #
    #   * **:examples** => number of examples ran
    #   * **:failures** => number of failed examples
    #   * **:pending** => number of pending examples ran
    #   * **:summary** => the summary string from which the above have been extracted
    #   * **:status**  => one of ```:failure, :pending, :success```
    def extract_rspec_stats(output, line_number)
      summary_line = output.split("\n")[line_number]
      summary_regex = /^(\d*)\sexamples?,\s(\d*)\s(errors?|failures?)[^\d]*((\d*)\spending)?/
      matchdata = summary_line.match(summary_regex)
      raise SummaryExtractionError.new  if matchdata.nil?
      _, examples, failures, _, pending = matchdata.to_a
      stats = {:examples => examples.to_i, :failures => failures.to_i, :pending => pending.to_i, :summary => summary_line}
      stats.merge(:status =>  rspec_status(stats))
    end

    # Returns a hash that summarizes the rspec results.
    #
    # Redefine this method if you are using a non standard rspec formatter,
    # see the {file:README.md} for details.
    # @param [String] output the rspec output
    # @return [Hash] a hash table with keys ```:examples, :failures, :pending, :summary, :status```.
    #
    #   * **`:examples`**: number of examples ran
    #   * **`:failures`**: number of failed examples
    #   * **`:pending`**: number of pending examples ran
    #   * **`:summary`**: the summary string from which the above have been extracted
    #   * **`:status`**: one of
    #
    #        ```
    #        :success, :pending, :failure
    #        ```
    def extract_rspec_summary(output)
      begin
        extract_rspec_stats output, @summary_line_number
      rescue SummaryExtractionError
        puts  "--- Error while extracting summary with the default method.".red
        print "--- Summary line number: ".yellow
        @summary_line_number = STDIN.gets.to_i
        extract_rspec_summary output
      end
    end

    # Runs a command and returns a hash containing exit status,
    # standard output and standard error contents.
    #
    # @return [Hash] a hash table with keys `:status, :stdout, :stderr`.
    def run(cmd)
      puts "=== running: #{cmd} ".ljust(terminal_columns, '=').cyan
      pid, _, stdout, stderr = Open4::popen4 cmd
      _, status = Process::waitpid2 pid
      puts "===".ljust(terminal_columns, '=').cyan
      {:status => status, :stdout => stdout.read.strip, :stderr => stderr.read.strip}
    end

    # Sends a notification to emacs via Enotify
    #
    # @param [String] rspec_output The rspec command output
    # @param [Hash] stats A Hash table with keys ```:examples, :failures, :pending, :summary, :status```.
    #    See {#extract_rspec_summary} for details about the meaning of the key/value pairs in this table.
    def rspec_send_results(rspec_output, stats)
      begin
        print "--- Sending notification to #{@enotify_host}:#{@enotify_port}" \
        " through #{@enotify_slot_id}... ".cyan
        enotify_notify rspec_output, stats
        puts "Success!".green
      rescue SocketError
        puts "Failed!".red
        enotify_connect
        rspec_send_results rspec_output, stats
      end
    end

    # Checks if the commands `bundle exec rspec` and `rspec` actually
    # run the same program, and sets the `@bundle` instance variable
    # accordingly.
    #
    # This is meant to speed up the execution of `rspec`.
    def check_if_bundle_needed
      if `bundle exec #{rspec_command} -v` == `#{rspec_command} -v`
        @bundle = ""
      else
        @bundle = "bundle exec "
      end
    end

    # Runs the `rspec` command with the given options, and notifies Emacs of the results.
    #
    # @param [String] options The command line arguments to pass to rspec.
    def rspec(options)
      unless options.empty?
        results = run("#{@bundle}#{rspec_command} --failure-exit-code 99 #{options}")
        status = results[:status].exitstatus
        if status == 1
          puts "An error occurred when running the tests".red
          puts "RSpec output:"
          puts "STDERR:"
          puts results[:stderr]
          puts "-" * 80
          puts "STDOUT:"
          puts results[:stdout]
        else
          begin
            stats = extract_rspec_summary results[:stdout]
            puts(stats[:summary].send(results[:status] == 0 ? :green : :red))
            # enotify_notify results[:stdout], stats
            rspec_send_results results[:stdout], stats
          rescue StandardError => e
            puts "ERROR extracting summary from rspec output: #{e}".red
            puts e.backtrace
            puts "RSpec output:"
            puts "STDERR:"
            puts results[:stderr]
            puts "-" * 80
            puts "STDOUT:"
            puts results[:stdout]
            print "Exit? (y/N)"
            answer = STDIN.gets
            abort "Execution aborted by the user"  if answer.strip.downcase == 'y'
          end
        end
      end
    end
  end

  # This module contains all the functions used to interact with the Enotify emacs mode-line notification system.
  module Emacs
    # Sends a message to the Enotify host.
    #
    # @param [Object] object the object to be serialized as a lisp
    #   object (with the {Object#to_lisp} method) and sent as a message.
    def enotify_send(object)
      sexp = object.to_lisp
      @sock.puts "|#{sexp.length}|#{sexp}"
    end

    # Registers the slot named `@enotify_slot_id` with Enotify.
    def enotify_register
      enotify_send :register => @enotify_slot_id, :handler_fn => "tdd"
    end

    # Sends a notification to the enotify host with the RSpec results.
    #
    # @param [String] stdout the rspec command output.
    # @param [Hash] stats the extracted summary of the results. For
    #   details, see the return value of
    #   {Spectator::Specs#extract_rspec_summary} for details.
    def enotify_notify(stdout, stats)
      #stats = extract_rspec_stats stdout
      status = stats[:status]
      message = {
        :id => @enotify_slot_id,
        :notification => {
          :text => @notification_messages[status],
          :face => @notification_face[status],
          :help => format_tooltip(stats),
          :mouse_1 => "tdd"
        },
        :data => stdout
      }

      enotify_send message
    end

    # Checks whether the string is made by whitespace characters.
    #
    # @param [String] string the string to be checked
    # @return [Boolean] non nil if the string is blank, nil otherwise.
    def blank_string?(string)
      string =~ /\A\s*\n?\z/
    end

    # Interactively retries to connect to the Enotify host, asking a
    # new *host:port* value.
    def rescue_sock_error
      print "--- Enter Enotify host [localhost:5000]: ".yellow
      host_and_port = STDIN.gets.strip
      if blank_string?(host_and_port)
        @enotify_host, @enotify_port = ['localhost', @default_options[:enotify_port]]
      else
        @enotify_host, @enotify_port = host_and_port.split(/\s:\s/)
        @enotify_port = @enotify_port.to_i
      end
      enotify_connect
    end

    # Creates a connection to the Enotify host.
    def enotify_connect
      begin
        print "=== Connecting to emacs... ".cyan
        @sock = TCPSocket.new(@enotify_host, @enotify_port)
        enotify_register
        puts "Success!".green
      rescue SocketError, Errno::ECONNREFUSED => e
        puts "Failed!".red
        rescue_sock_error
      end
    end

    # Formats the text that will be used as a tooltip for the modeline
    # *"icon"*.
    #
    # @param [Hash] stats the extracted summary of the results. For
    #   details, see the return value of
    #   {Spectator::Specs#extract_rspec_summary} for details.
    def format_tooltip(stats)
      t = Time.now
      "#{t.year}-#{t.month}-#{t.day} -- #{t.hour}:#{t.min}:#{t.sec}\n" +
        "#{stats[:examples]} examples, #{stats[:failures]} failures" +
        ((stats[:pending] > 0) ? ", #{stats[:pending]} pending.\n" : ".\n") +
        "\nmouse-1: switch to rspec output buffer"
    end

  end


  # This is the class that implements the main loop of spectator-emacs.
  # To run spectator-emacs, just create a new ERunner object.
  class ERunner < Runner
    include Specs
    include Emacs
    # Creates a new instance of ERunner. This implements the main loop of `spectator-emacs`.
    # See the {file:README.md} for examples on how to customize the default behavior.
    # @param [Hash] options possible options are:
    #
    #   ##### :enotify_port (Fixnum)
    #   the port the Enotify host is listening to.
    #   ##### :enotify_host`({String})
    #   the host name or IP address where Enotify is running.
    #   ##### :notification_messages ({Hash})
    #   a hash with keys `:success, :failure, :pending` containing the
    #   relative modeline *icons* strings.
    #   Defaults to `{:success => "S", :failure => "F", :pending => "P"}`.
    #   ##### :notification_face ({Hash})
    #   A hash table with keys `:success, :failure, :pending` containing
    #   the faces to apply to the notification *icon* in the Emacs modeline.
    #   Values must be {Symbol}s, like for example `:font_lock_constant_face`
    #   in order to use Emacs' `font-lock-warning-face`.
    #   Defaults to
    #
    #      ```
    #      {:success => :\':success\', :failure => :\':failure\', :pending => :\':warning\'}
    #      ```
    # @yield [ERunner] Gives a reference of the ERunner object just created to the block
    #   Use this block when you need to customize the behavior of spectator-emacs.
    #   For example, if you need a custom summary extraction method, you can create
    #   the runner object as follows in your `.spectator-emacs` script:
    #
    #   ```ruby
    #   @runner = ERunner.new do |runner|
    #     def runner.extract_rspec_summary(output)
    #       ## your summary extraction code here
    #       ## ...
    #     end
    #   end
    #   ```
    def initialize(options={}, &block)
      @default_options = {
        :enotify_port => 5000,
        :enotify_host => 'localhost',
        :notification_messages => {:failure => "F", :success => "S", :pending => "P"},
        :notification_face => {
          :failure => :failure.keyword,
          :success => :success.keyword,
          :pending => :warning.keyword
        }
      }
      options = @default_options.merge options
      @cli_args = ARGV.to_a
      puts "======= OPTIONS ======="
      options.each {|k, v| puts "#{k} => #{v}"}
      @enotify_host = options[:enotify_host]
      @enotify_port = options[:enotify_port]
      @notification_messages = options[:notification_messages]
      @notification_face = options[:notification_face]
      @summary_line_number = options[:summary_line] || -1
      @enotify_slot_id = options[:slot_id] ||
        ((File.basename Dir.pwd).split('_').map {|s| s.capitalize}).join.gsub('-','/')
      check_if_bundle_needed
      enotify_connect
      yield self  if block_given?
      # TODO: load .spectator-emacs
      # contents = File::read('.spectator-emacs')
      # eval(contents)
      super()
    end
  end
end
#####################################
# require 'spectator/emacs'

# Spectator::ERunner.new(:enotify_port => 5001, :enotify_host => 'localhost') do |runner|
#   def runner.extract_rspec_stats(results, line)
#     ## define new spec extraction routine
#     ## it must return a hash like this one:
#     ## {:examples => 10,   # number of examples executed
#     ##  :failures => 4,    # number of failures
#     ##  :pending => 1,     # number of pending examples
#     ##  :status => :failure # one of :pending, :succes, :failure
#     ## }
#   end
# end
