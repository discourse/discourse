require "rspec/core/formatters/base_formatter"

module Autospec; end
class Autospec::Formatter < RSpec::Core::Formatters::BaseFormatter

  def dump_summary(duration, total, failures, pending)
    failed_specs = examples.delete_if{|e| e.execution_result[:status] != "failed"}.map{|s| s.metadata[:location]}

    # if this fails don't kill everything
    begin
      FileUtils.mkdir_p('tmp')
      File.open("./tmp/rspec_result","w") do |f|
        f.puts failed_specs.join("\n")
      end
    rescue
      # nothing really we can do, at least don't kill the test runner
    end
  end

end
