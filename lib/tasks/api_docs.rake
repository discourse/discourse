# frozen_string_literal: true

# Only define this task when in development/test environments
# This prevents LoadError when running other rake tasks in environments without test gems
if Rails.env.local?
  require "rspec/core/rake_task"

  # Override the default rswag:specs:swaggerize task to include plugin API specs
  namespace :rswag do
    namespace :specs do
      # Clear the existing task so we can redefine it
      if Rake::Task.task_defined?("rswag:specs:swaggerize")
        Rake::Task["rswag:specs:swaggerize"].clear
      end

      desc "Generate Swagger JSON files from integration specs (including plugins)"
      RSpec::Core::RakeTask.new("swaggerize") do |t|
        # Automatically load plugins for API documentation
        ENV["LOAD_PLUGINS"] = "1" unless ENV["LOAD_PLUGINS"]

        # Include plugin API specs in the pattern
        t.pattern =
          ENV.fetch(
            "PATTERN",
            "spec/requests/**/*_spec.rb, spec/api/**/*_spec.rb, spec/integration/**/*_spec.rb, plugins/*/spec/requests/api/*_spec.rb",
          )

        additional_rspec_opts = ENV.fetch("ADDITIONAL_RSPEC_OPTS", "")

        t.rspec_opts = [additional_rspec_opts]

        if Rswag::Specs.config.rswag_dry_run
          t.rspec_opts += [
            "--format Rswag::Specs::SwaggerFormatter",
            "--dry-run",
            "--order defined",
          ]
        else
          t.rspec_opts += ["--format Rswag::Specs::SwaggerFormatter", "--order defined"]
        end
      end
    end
  end
end
