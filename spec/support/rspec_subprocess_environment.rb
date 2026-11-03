# frozen_string_literal: true
module RSpecSubprocessEnvironment
  private

  def isolated_rspec_environment
    {
      "RUBYOPT" => "-rbundler/setup",
      "TEST_SELECTION_ORIGINAL_RUBYOPT" => nil,
      "TEST_MAPPING_COLLECT" => nil,
      "COLLECT_TEST_MAPPING" => nil,
      "COLLECT_RSPEC_MAPPING" => nil,
      "RSPEC_MAPPING_DIRECTORY" => nil,
      "TEST_MAPPING_DIRECTORY" => nil,
      "TEST_EXECUTION_DIRECTORY" => nil,
      "TEST_SELECTION_ROOT" => nil,
      "TEST_SELECTION_INVENTORY" => nil,
      "TEST_SELECTION_ENVIRONMENT" => nil,
      "TEST_SELECTION_ALL" => nil,
      "TEST_ENV_NUMBER" => nil,
      "TEST_MAPPING_PROCESS_ID" => nil,
    }
  end
end
