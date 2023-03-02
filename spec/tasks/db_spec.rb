# frozen_string_literal: true

RSpec.describe "tasks/db" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  describe "db:status:json" do
    it "returns the right json output" do
      expect { Rake::Task["db:status:json"].invoke }.to output(
        /"status":"ok","migrated":true/,
      ).to_stdout
    end
  end
end
