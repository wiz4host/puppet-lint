require 'puppet-lint/version'
require 'puppet-lint/lexer'
require 'puppet-lint/configuration'
require 'puppet-lint/plugin'
require 'puppet-lint/bin'
require 'puppet-lint/monkeypatches'

class PuppetLint::NoCodeError < StandardError; end

class PuppetLint
  attr_accessor :code

  # Public: Initialise a new PuppetLint object.
  def initialize
    @code = nil
    @statistics = {:error => 0, :warning => 0}
    @fileinfo = {:path => ''}
  end

  # Public: Access PuppetLint's configuration from outside the class.
  #
  # Returns a PuppetLint::Configuration object.
  def self.configuration
    @configuration ||= PuppetLint::Configuration.new
  end

  # Public: Access PuppetLint's configuration from inside the class.
  #
  # Returns a PuppetLint::Configuration object.
  def configuration
    self.class.configuration
  end

  def file=(path)
    if File.exist? path
      @fileinfo[:path] = path
      @fileinfo[:fullpath] = File.expand_path(path)
      @fileinfo[:filename] = File.basename(path)
      @code = File.read(path)
    end
  end

  def log_format
    if configuration.log_format == ''
      ## recreate previous old log format as far as thats possible.
      format = '%{KIND}: %{message} on line %{linenumber}'
      if configuration.with_filename
        format.prepend '%{path} - '
      end
      configuration.log_format = format
    end
    return configuration.log_format
  end

  def format_message(message)
    format = log_format
    puts format % message
  end

  def print_context(message, linter)
    # XXX: I don't really like the way this has been implemented (passing the
    # linter object down through layers of functions.  Refactor me!
    return if message[:check] == 'documentation'
    line = linter.manifest_lines[message[:linenumber] - 1]
    offset = line.index(/\S/)
    puts "\n  #{line.strip}"
    printf "%#{message[:column] + 2 - offset}s\n\n", '^'
  end

  def report(problems, linter)
    problems.each do |message|
      @statistics[message[:kind]] += 1

      message.merge!(@fileinfo) {|key, v1, v2| v1 }
      message[:KIND] = message[:kind].to_s.upcase

      if [message[:kind], :all].include? configuration.error_level
        format_message message
        print_context(message, linter) if configuration.with_context
      end
    end
  end

  # Public: Determine if PuppetLint found any errors in the manifest.
  #
  # Returns true if errors were found, otherwise returns false.
  def errors?
    @statistics[:error] != 0
  end

  # Public: Determine if PuppetLint found any warnings in the manifest.
  #
  # Returns true if warnings were found, otherwise returns false.
  def warnings?
    @statistics[:warning] != 0
  end

  # Public: Run the loaded manifest code through the lint checks and print the
  # results of the checks to stdout.
  #
  # Returns nothing.
  # Raises PuppetLint::NoCodeError if no manifest code has been loaded.
  def run
    if @code.nil?
      raise PuppetLint::NoCodeError
    end

    linter = PuppetLint::Checks.new
    problems = linter.run(@fileinfo, @code)
    report problems, linter
  end
end

# Default configuration options
PuppetLint.configuration.defaults

require 'puppet-lint/plugins'
