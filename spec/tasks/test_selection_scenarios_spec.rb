# frozen_string_literal: true
require "open3"
require "tmpdir"
require "rbconfig"
require_relative "../support/rspec_subprocess_environment"
require_relative "../../script/ci/test_selection_lab/shared_state_scenarios"

RSpec.describe "Dependency selection scenarios" do
  include RSpecSubprocessEnvironment

  TestSelectionLab::SHARED_STATE_SCENARIOS.each do |name, *_|
    it "selects affected files for #{name}" do
      Dir.mktmpdir("dependency-scenario-") do |workspace|
        output, error, status =
          Open3.capture3(
            isolated_rspec_environment,
            RbConfig.ruby,
            "script/ci/test_selection_lab/shared_state.rb",
            workspace,
            name,
          )

        expect(status.success?).to eq(true), "#{output}\n#{error}"
      end
    end
  end
end
