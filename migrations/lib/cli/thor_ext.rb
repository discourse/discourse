# frozen_string_literal: true

# Based on code from https://mattbrictson.com/blog/fixing-thor-cli-behavior
#
# Configures Thor to behave more like a typical CLI, with better help and error handling.
#
# - Passing -h or --help to a command will show help for that command.
# - Unrecognized options will be treated as errors (instead of being silently ignored).
# - Error messages will be printed in red to stderr, without stack trace.
# - Full stack traces can be enabled by setting the VERBOSE environment variable.
# - Errors will cause Thor to exit with a non-zero status.

# The MIT License (MIT)
#
# Copyright (c) 2023 Matt Brictson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module Migrations::CLI
  module ThorExt
    def self.extended(base)
      super
      base.check_unknown_options!
    end

    def start(given_args = ARGV, config = {})
      config[:shell] ||= Thor::Base.shell.new
      handle_help_switches(given_args) { |args| dispatch(nil, args, nil, config) }
    rescue StandardError => e
      handle_exception_on_start(e, config)
    end

    private

    def handle_help_switches(given_args)
      yield(given_args.dup)
    rescue Thor::UnknownArgumentError => e
      retry_with_args = []

      if given_args.first == "help"
        retry_with_args = ["help"] if given_args.length > 1
      elsif e.unknown.intersect?(%w[-h --help])
        retry_with_args = ["help", (given_args - e.unknown).first]
      end
      raise if retry_with_args.none?

      yield(retry_with_args)
    end

    def handle_exception_on_start(error, config)
      return if error.is_a?(Errno::EPIPE)
      raise if ENV["VERBOSE"] || !config.fetch(:exit_on_failure, true)

      message = error.message.to_s
      message = ("[#{error.class}] #{message}") if message.empty? || !error.is_a?(Thor::Error)

      config[:shell]&.say_error(message, :red)
      exit(false)
    end
  end
end
