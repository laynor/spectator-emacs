#require 'spectator/emacs/version'
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
  def to_lisp
    to_s.gsub "_", "-"
  end

  # # giovanni cane
  # Returns a **symbol** with the same name prefixed by a colon. This is
  # convenient when converting a symbol with the to_lisp method.
  #
  # ```
  # def foo
  #   puts "bar"
  # end
  # ```
  #
  def keyword
    if self[0] == ':'
      self
    else
      ":#{to_s}".to_sym
    end
  end
end

class String
  def to_lisp
    inspect
  end
end

class Array
  def to_lisp
    sexp_array = map { |el| el.to_lisp }
    "(#{sexp_array.join ' '})"
  end
end

class Hash
  # Creates and returns a new hash tabke with the same keys and values
  # and tags it to be rendered as an association list by the to_lisp
  # method.
  # For example, {:a => :b, :x => 1} would be rendered as
  #   ((a . b) (x . 1))
  def as_alist
    merge(:__render_as => :alist)
  end

  # Creates and returns a new hash tabke with the same keys and values
  # but tagged to be rendered as a flat list by the to_lisp method.
  # For example, {:a => :b, :x => 1} would be rendered as
  #   (a b x 1)
  def as_flat_list
    merge(:__render_as => :flat )
  end

  # Creates and returns a new hash tabke with the same keys and values
  # but tagged to be rendered as a property list by the to_lisp method.
  # The keys must be symbols, and they will be rendered as keywords.
  # For example, {:a => :b, :x => 1} would be rendered as
  #   (:a b :x 1)
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
  class SummaryExtractionError < RuntimeError
  end

  module Specs
    def rspec_status(rspec_stats)
      if rspec_stats[:failures] > 0
        :failure
      elsif rspec_stats[:pending] > 0
        :pending
      else
        :success
      end
    end

    def extract_rspec_stats(output, line)
      summary_line = output.split("\n")[line]
      summary_regex = /^(\d*)\sexamples?,\s(\d*)\s(errors?|failures?)[^\d]*((\d*)\spending)?/
      matchdata = summary_line.match(summary_regex)
      raise SummaryExtractionError.new  if matchdata.nil?
      _, examples, failures, _, pending = matchdata.to_a
      # We need to
      stats = {:examples => examples.to_i, :failures => failures.to_i, :pending => pending.to_i, :summary => summary_line}
      stats.merge(:status =>  rspec_status(stats))
    end

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


    def run(cmd)
      puts "=== running: #{cmd} ".ljust(terminal_columns, '=').cyan
      pid, _, stdout, stderr = Open4::popen4 cmd
      _, status = Process::waitpid2 pid
      puts "===".ljust(terminal_columns, '=').cyan
      {:status => status, :stdout => stdout.read.strip, :stderr => stderr.read.strip}
    end

    def rspec_send_results(results, stats)
      begin
        print "--- Sending notification to #{@enotify_host}:#{@enotify_port}" \
        " through #{@enotify_slot_id}... ".cyan
        enotify_notify results, stats
        puts "Success!".green
      rescue SocketError
        puts "Failed!".red
        enotify_connect
        rspec_send_results results,stats
      end
    end

    def check_if_bundle_needed
      if `bundle exec #{rspec_command} -v` == `#{rspec_command} -v`
        @bundle = ""
      else
        @bundle = "bundle exec "
      end
    end

    def rspec(options)
      unless options.empty?
        results = run("#{@bundle}#{rspec_command} --failure-exit-code 99 #{options}")
        status = results[:status].exitstatus
        if status == 99
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

  module Emacs
    def enotify_send(object)
      sexp = object.to_lisp
      @sock.puts "|#{sexp.length}|#{sexp}"
    end

    def enotify_register
      enotify_send :register => @enotify_slot_id, :handler_fn => :enotify_rspec_result_message_handler
    end

    def enotify_notify(stdout, stats)
      #stats = extract_rspec_stats stdout
      status = stats[:status]
      message = {
        :id => @enotify_slot_id,
        :notification => {
          :text => @notification_messages[status],
          :face => @notification_face[status],
          :help => format_tooltip(stats),
          :mouse_1 => :enotify_rspec_mouse_1_handler
        },
        :data => stdout
      }

      enotify_send message
    end

    def blank_string?(string)
      string =~ /\A\s*\n?\z/
    end

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

    def enotify_connect
      begin
        print "=== Connecting to emacs... ".cyan
        @sock = TCPSocket.new(@enotify_host, @enotify_port)
        enotify_register
        puts "Success!".green
      rescue SocketError
        puts "Failed!".red
        rescue_sock_error
      end
    end

    def format_tooltip(stats)
      t = Time.now
      "#{t.year}-#{t.month}-#{t.day} -- #{t.hour}:#{t.min}:#{t.sec}\n" +
        "#{stats[:examples]} examples, #{stats[:failures]} failures" +
        ((stats[:pending] > 0) ? ", #{stats[:pending]} pending.\n" : ".\n") +
        "\nmouse-1: switch to rspec output buffer"
    end

  end


  class ERunner < Runner
    include Specs
    include Emacs
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
      # @summary_line_number = options[:summary_line] || -2
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
