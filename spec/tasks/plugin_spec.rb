# frozen_string_literal: true

RSpec.describe "Plugin rake tasks" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    STDOUT.stubs(:write)
  end

  describe "plugin:create" do
    def invoke(plugin_name)
      error = nil
      stdout =
        capture_stdout do
          Rake::Task["plugin:create"].invoke(plugin_name)
        rescue => e
          error = e
        end
      [error, stdout]
    end

    it "should abort if name is blank" do
      error, stdout = invoke ""
      expect(error).to be_a(ArgumentError)
      expect(stdout).to include("You must provide a plugin name")
    end

    it "should abort if not in kebab case" do
      error, stdout = invoke "MyPlugin"
      expect(error).to be_a(ArgumentError)
      expect(stdout).to include("Name must be in kebab-case")
    end

    it "should create a plugin" do
      error, stdout = invoke "my-plugin"
      expect(error).to eq(nil)
      expect(stdout).to include("Initialized empty Git repository")
    end
  end
end
