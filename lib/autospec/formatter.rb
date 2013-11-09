require "rspec/core/formatters/base_text_formatter"

module Autospec; end

class Autospec::Formatter < RSpec::Core::Formatters::BaseTextFormatter

  RSPEC_RESULT = "./tmp/rspec_result"

  def initialize(output)
    super
    FileUtils.mkdir_p("tmp") unless Dir.exists?("tmp")
  end

  def start(example_count)
    super
    File.delete(RSPEC_RESULT) if File.exists?(RSPEC_RESULT)
    @fail_file = File.open(RSPEC_RESULT,"w")
  end

  def example_passed(example)
    super
    output.print success_color(".")
  end

  def example_pending(example)
    super
    output.print pending_color("*")
  end

  def example_failed(example)
    super
    output.print failure_color("F")
    @fail_file.puts(example.metadata[:location] + " ")
    @fail_file.flush
  end

  def start_dump
    super
    output.puts
  end

  def close
    @fail_file.close
  end

end
