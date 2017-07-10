require 'test/unit'
require File.expand_path('../../../lib/unix_crypt', __FILE__)
require File.expand_path('../../../lib/unix_crypt/command_line', __FILE__)

class CommandLineTest < Test::Unit::TestCase
  class CaptureIO
    def initialize(name, buffer, input = [])
      @name = name
      @buffer = buffer
      @input = input
    end

    def noecho
      yield self
    end

    def gets
      @buffer << [@name, @input.first.dup]
      @input.shift
    end

    def write(data)
      @buffer << [@name, data]
    end

    def print(data)
      write data
    end

    def puts(data = "")
      write "#{data}\n"
    end

    def self.redirect(input = [])
      buffer = []
      $stdin = new("stdin", buffer, input)
      $stdout = new("stdout", buffer)
      $stderr = new("stderr", buffer)
      yield
      buffer
    ensure
      $stdin = STDIN
      $stdout = STDOUT
      $stderr = STDERR
    end
  end

  def test_no_parameter_password_creation
    result = CaptureIO.redirect(["hello\n", "hello\n"]) do
      UnixCrypt::CommandLine.new([]).encrypt
    end

    expected = [
      ["stderr", "Enter password: "],
      ["stdin", "hello\n"],
      ["stderr", "\n"],
      ["stderr", "Verify password: "],
      ["stdin", "hello\n"],
      ["stderr", "\n"]
    ]

    assert_equal expected, result[0..-2]

    channel, password = result[-1]
    assert_equal "stdout", channel
    assert_match %r{\A\$6\$[a-zA-Z0-9./]{16}\$[a-zA-Z0-9./]{86}\n\z}, password

    assert UnixCrypt.valid?("hello", password)
  end

  def test_parameters_provided_password_creation
    result = CaptureIO.redirect do
      UnixCrypt::CommandLine.new(%w(-h sha256 -p hello -s salty -r 1234)).encrypt
    end

    expected = [
      ["stderr", "warning: providing a password on the command line is insecure\n"]
    ]

    assert_equal expected, result[0..-2]

    channel, password = result[-1]
    assert_equal "stdout", channel
    assert_match %r{\A\$5\$rounds=1234\$salty\$[a-zA-Z0-9./]{43}\n\z}, password

    assert UnixCrypt.valid?("hello", password)
  end
end
