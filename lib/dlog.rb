require "logger"

module Dlog
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
  
  def self.log(context, args)
    severity = if args.first.is_a?(Symbol)
      args.shift
    else
      :info
    end

    msg = ""
    was_string = true
    args.map do |s|
      msg += was_string ? " " : ", " unless msg.empty?
      msg += ((was_string = s.is_a?(String)) ? s : s.inspect)
    end

    msg = "#{release? ? rlog_caller : dlog_caller} #{msg}"

    logger = context.send(:dlogger) || self.logger
    logger.send severity, msg

    if irb? && !log_to_stderr?
      STDERR.puts msg
    end
  end
  
  def self.irb?
    caller.detect do |s| s =~ /irb\/workspace.rb/ end
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
  def self.rlog_caller
    if caller[2] =~ /^(.*):(\d+)/
      file, line = $1, $2
      "[" + File.basename(file).sub(/\.[^\.]*$/, "") + "]"
    else
      "[log]"
    end
  end

  #
  # get a caller description, for debug mode 
  def self.dlog_caller
    if caller[2] =~ /^(.*):(\d+)/
      file, line = $1, $2
      file = File.expand_path(file)

      file.gsub!(ROOT, ".") or
      file.gsub!(HOME, "~/")

      "#{file}(#{line}):"
    else
      "<dlog>:"
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
end

class Object
  def rlog(*args)
    return if Dlog.quiet?
    Dlog.log self, args
  end
  
  def dlog(*args)
    return if Dlog.quiet? || Dlog.release?
    Dlog.log self, args
  end
  
  def benchmark(*args, &block)
    start = Time.now
    r = yield
    args.push ": %3d msecs" % (1000 * (Time.now - start))
    rlog *args
    r
  rescue
    args.push ": exception raised after #{"%3d msecs" % (1000 * (Time.now - start)) }"
    rlog *args
    raise
  end
  
  private
  
  def dlogger; nil; end
end
