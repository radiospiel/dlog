require "logger"

module Dlog
  module Color
    extend self
    
    def color(id)
      "\e[#{id}m"
    end

    RED = color 31
    GREEN = color 32
    YELLOW = color 33
    BLUE = color 34
    MAGENTA = color 35
    CYAN = color 36
    DARK_GREY = color "1;30"
    LIGHT_RED = color "1;31"
    LIGHT_GREEN = color "1;32"
    LIGHT_YELLOW = color "1;33"
    LIGHT_BLUE = color "1;34"
    LIGHT_MAGENTA = color "1;35"
    LIGHT_CYAN = color "1;36"
    
    CLEAR = color 0
    
    def error(msg);  "#{LIGHT_RED}#{msg}#{CLEAR}"; end
    def warn(msg);   "#{LIGHT_YELLOW}#{msg}#{CLEAR}"; end
    def info(msg);   "#{GREEN}#{msg}#{CLEAR}"; end
    def debug(msg);  msg; end
  end
  
  #
  # The logger device.
  def self.logger=(logger)
    @logger = logger
  end
  
  def self.logger
    @logger ||= if defined?(RAILS_DEFAULT_LOGGER)
      RAILS_DEFAULT_LOGGER
    else
      logger = Logger.new(STDERR)
      logger.formatter = StderrFormatter
      logger
    end
  end
  
  def self.log(severity, args, source_offset = 1)
    msg = ""
    was_string = true
    args.map do |s|
      msg += was_string ? " " : ", " unless msg.empty?
      msg += ((was_string = s.is_a?(String)) ? s : s.inspect)
    end

    source = caller[source_offset]
    msg = "#{release? ? rlog_caller(source) : dlog_caller(source)} #{msg}"
    msg = Color.send severity, msg
    
    logger = self.logger
    logger.send severity, msg

    if irb? && !log_to_stderr?
      STDERR.puts msg
    end
    
    args.first
  end
  
  def self.irb?
    caller.detect do |s| s =~ /irb\/workspace.rb/ end != nil
  end
  
  def self.log_to_stderr?
    logdev = logger.instance_variable_get("@logdev")
    logdev.dev == STDERR if logdev.respond_to?(:dev)
  end
  
  # Logging formatter
  module Formatter
    # formatter#call is invoked with 4 arguments: severity, time, progname
    # and msg for each log. Bear in mind that time is a Time and msg is an
    # Object that user passed and it could not be a String. 
    def self.call(severity, time, progname, msg)
      time.strftime("%Y-%m-%d %H:%M:%S #{severity}: #{msg}")
    end
  end

  module StderrFormatter
    # formatter#call is invoked with 4 arguments: severity, time, progname
    # and msg for each log. Bear in mind that time is a Time and msg is an
    # Object that user passed and it could not be a String. 
    def self.call(severity, time, progname, msg)
      "#{msg}\n"
    end
  end
  
  #
  # get a caller description, for release mode 
  def self.rlog_caller(source)
    if source =~ /^(.*):(\d+)/
      file, line = $1, $2
      file, line = $1, $2
      if file == "(irb)"
        "[irb]:"
      else
        "[" + File.basename(file).sub(/\.[^\.]*$/, "") + "]:"
      end
    else
      "[log]"
    end
  end

  #
  # get a caller description, for debug mode 
  def self.dlog_caller(source)
    if source =~ /^(.*):(\d+)/
      file, line = $1, $2
      if file == "(irb)"
        "[irb]:"
      else
        file = File.expand_path(file)

        file.gsub!(ROOT, ".") or
        file.gsub!(HOME, "~/")

        "#{file}(#{line}):"
      end
    else
      "[dlog]:"
    end
  end

  #
  # The applications ROOT dir, to shorten the source line 
  ROOT = if defined?(RAILS_ROOT)
    RAILS_ROOT
  else
    File.expand_path(Dir.getwd) 
  end
  
  # The user's HOME dir, to shorten the source line 
  HOME = ENV["HOME"] + "/"

  # -- dlog modi ------------------------------------------------------
  
  @@mode = :debug
  
  def self.release!(&block); set_mode :release, &block; end
  def self.debug!(&block); set_mode :debug, &block; end
  def self.quiet!(&block); set_mode :quiet, &block; end

  def self.release?; @@mode == :release; end
  def self.debug?; @@mode == :debug; end
  def self.quiet?; @@mode == :quiet; end

  def self.set_mode(mode, &block)
    if !block_given?
      old = mode
    else
      old, @@mode = @@mode, mode
      yield
    end
  ensure
    @@mode = old
  end

  def self.error(*args)
    log :error, args
  end

  def self.warn(*args)
    log :warn, args
  end
    
  def self.info(*args)
    log :info, args
  end
    
  def self.debug(*args)
    log :debug, args
  end
  
  module Nolog
    extend self
  
    def error(*args); args.first; end
    def warn(*args); args.first; end
    def info(*args); args.first; end
    def debug(*args); args.first; end
  end
  
  module NoBenchmark
    extend self
    
    def error(*args, &block); yield; end
    def warn(*args, &block); yield; end
    def info(*args, &block); yield; end
    def debug(*args, &block); yield; end
  end
  
  module Benchmark
    extend self
    
    def benchmark(severity, args, &block)
      args.push "#{args.pop}:" if args.last.is_a?(String)

      start = Time.now
      r = yield

      args.push "%d msecs" % (1000 * (Time.now - start))
      Dlog.log severity, args, 2
      r
    rescue
      args.push "exception raised after #{"%d msecs" % (1000 * (Time.now - start)) }"
      Dlog.log severity, args, 2
      raise
    end
    
    def error(*args, &block)
      benchmark :error, args, &block
    end

    def warn(*args, &block)
      benchmark :warn, args, &block
    end
    def info(*args, &block)
      benchmark :info, args, &block
    end
    def debug(*args, &block)
      benchmark :debug, args, &block
    end
  end

  module Benchslow
    include Benchmark
    extend self
    
    def benchmark(severity, args, &block)
      args.push "#{args.pop}:" if args.last.is_a?(String)

      start = Time.now
      r = yield

      timespan = Time.now - start
      if timespan > 1
        args.push "%d msecs" % (1000 * timespan)
        Dlog.log severity, args, 2
      end

      r
    rescue
      args.push "exception raised after #{"%d msecs" % (1000 * (Time.now - start)) }"
      Dlog.log severity, args, 2
      raise
    end
  end
end

class Object
  def dlog(*args)
    quiet = Dlog.quiet? || Dlog.release?
    
    if args.empty?
      quiet ? Dlog::Nolog : Dlog
    else
      Dlog.log :info, args unless quiet
      args.last
    end 
  end
  
  def rlog(*args)
    quiet = Dlog.quiet?
    
    if args.empty?
      quiet ? Dlog::Nolog : Dlog
    else
      Dlog.log :warn, args unless quiet
      args.last
    end 
  end
  
  def benchmark(*args, &block)
    if Dlog.quiet?
      Dlog::NoBenchmark
    elsif args.empty? && !block_given?
      Dlog::Benchmark 
    else
      Dlog::Benchmark.benchmark :info, args, &block
    end
  end
  
  def benchslow(*args, &block)
    if Dlog.quiet?
      Dlog::NoBenchmark
    elsif args.empty? && !block_given?
      Dlog::Benchslow 
    else
      Dlog::Benchslow.benchmark :info, args, &block
    end
  end
  
  private
  
  def dlogger; nil; end
end
