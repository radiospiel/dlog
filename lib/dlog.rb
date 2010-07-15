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

    msg = "#{Dlog.release? ? rlog_caller : dlog_caller} #{msg}"

    logger = context.send(:dlogger) || Dlog.logger
    logger.send severity, msg
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
      msg
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
  
  #
  # set release mode.
  def self.release!
    @release = true
  end

  #
  # Is release mode active?
  def self.release?
    @release
  end
      
  #
  # set debug mode
  def self.debug!
    @release = false
  end

  #
  # is debug mode active?
  def self.debug?
    !@release
  end

  #
  # be quiet
  def self.quiet!
    @quiet = true
  end

  #
  # should we be quiet?
  def self.quiet?
    @quiet
  end
end

class Object
  def rlog(*args)
    return if Dlog.quiet? || Dlog.debug?
    Dlog.log self, args
  end
  
  def dlog(*args)
    return if Dlog.quiet?
    Dlog.log self, args
  end
  
  private
  
  def dlogger; nil; end
end
