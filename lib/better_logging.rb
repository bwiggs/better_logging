# This module, when included into ActiveSupport::BufferedLogger, improves the
# logging format. See the README file for more info.
#
# This is distributed under a Creative Commons "Attribution-Share Alike"
# license: for details see: 
# http://creativecommons.org/licenses/by-sa/3.0/
#
module PaulDowman
  module RailsPlugins
    module BetterLogging
      
      LENGTH = ActiveSupport::BufferedLogger::Severity.constants.map{|c| c.to_s.length}.max
      
      def self.included(base)
        base.class_eval do
          alias_method_chain :add, :extra_info
          alias_method_chain :error, :exception_param
          alias_method_chain :warn, :exception_param
        end
        
        # Get the length to format the output so that the pid column lines up.
        # The severity levels probably won't change but this avoids hard-coding
        # them anyway, just in case.
        # Most of this is done with class_eval so it should only be done once 
        # while the class is being loaded.
        if_stmts = ""
        for c in ActiveSupport::BufferedLogger::Severity.constants
          if_stmts += <<-EOT
            if severity == #{c}
              severity_name = sprintf("%1$*2$s", "#{c}", #{LENGTH * -1})
              if ActiveRecord::Base.colorize_logging
                if severity == INFO
                  severity_name = "\033[32m" + severity_name + "\033[0m"
                elsif severity == WARN
                  severity_name = "\033[33m" + severity_name + "\033[0m"
                elsif severity == ERROR || severity == FATAL
                  severity_name = "\033[31m" + severity_name + "\033[0m"
                end
              end
              return severity_name
            end
          EOT
        end
        base.class_eval <<-EOT, __FILE__, __LINE__
          def self.severity_name(severity)
            #{if_stmts}
            return "UNKNOWN"
          end
        EOT
      end
      

      def self.verbose=(boolean)
        @@verbose = boolean
      end
      
      def self.hostname_maxlen=(integer)
        @@hostname_maxlen = integer
        @@pid = format_pid_string
      end
            
      def self.format_pid_string
        if @@full_hostname.length < @@hostname_maxlen
          hostname = @@full_hostname
        else
          hostname = @@full_hostname[-(@@hostname_maxlen)..-1]
        end
        
        return sprintf("%1$*2$s", "#{hostname}.#{$$}", -(7 + hostname.length))
      end
      
      # set some default values:
      @@verbose = RAILS_ENV != "development"
      @@full_hostname = `hostname -s`.strip
      @@hostname_maxlen = 10
      @@pid = format_pid_string
      
      def add_with_extra_info(severity, message = nil, progname = nil, &block)
        time = @@verbose ? "#{Time.new.strftime('%H:%M:%S')}  " : ""
        message = "#{time}#{ActiveSupport::BufferedLogger.severity_name(severity)}  #{message}"
        
        # make sure every line starts with the pid so we can use grep to
        # isolate output from one process, gsub works even when the output 
        # contains "\n", though there's probably a small performance cost
        message = message.gsub(/^/, "#{@@pid}  ") if @@verbose
        add_without_extra_info(severity, message, progname, &block)
      end
      
      
      # add an optional second parameter to the error & warn methods to allow a stack trace:
            
      def error_with_exception_param(message, exception = nil)
        message += "\n#{exception.inspect}\n#{exception.backtrace.join("\n")}" if exception
        error_without_exception_param(message)
      end
      
      def warn_with_exception_param(message, exception = nil)
        message += "\n#{exception.inspect}\n#{exception.backtrace.join("\n")}" if exception
        warn_without_exception_param(message)
      end
    end
  end
end
