require "rspec/core/formatters/base_formatter"

module Autospec; end
class Autospec::Formatter < RSpec::Core::Formatters::BaseFormatter

  def dump_summary(duration, total, failures, pending)
    # failed_specs = examples.delete_if{|e| e.execution_result[:status] != "failed"}.map{|s| s.metadata[:location]}

    # # if this fails don't kill everything
    # begin
    #   FileUtils.mkdir_p('tmp')
    #   File.open("./tmp/rspec_result","w") do |f|
    #     f.puts failed_specs.join("\n")
    #   end
    # rescue
    #   # nothing really we can do, at least don't kill the test runner
    # end
    super
  end

  def start(count)
    FileUtils.mkdir_p('tmp')
    @fail_file = File.open("./tmp/rspec_result","w")
    super(count)
  end

  def close
    @fail_file.close
    super
  end

  def example_failed(example)
    @fail_file.puts example.metadata[:location]
    @fail_file.flush
    super(example)
  end


end
