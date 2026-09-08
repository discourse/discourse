# frozen_string_literal: true

require "open3"

RSpec.describe DiscourseEvents::Engine do
  it "reloads calendar helpers alongside their models" do
    # Reload in a separate process to avoid invalidating the suite's class references.
    script = <<~'RUBY'
      require_relative "config/application"

      Rails.application.config.before_initialize do
        Rails.application.config.enable_reloading = true
        Rails.application.config.eager_load = false
      end

      Rails.application.initialize!

      names = %w[
        DiscourseEvents::Calendar::Extractor
        DiscourseEvents::Calendar::Validator
        DiscourseEvents::Calendar::EventValidator
        DiscourseEvents::Holidays::Finder
        DiscourseEvents::Holidays::Status
        DiscourseEvents::Holidays::UsersOnHoliday
        DiscourseEvents::GroupTimezones::Extractor
        DiscourseEvents::Calendar::Event
        DiscourseEvents::Holidays::DisabledHoliday
      ]

      2.times do
        previous_classes = names.map(&:constantize)
        Rails.application.reloader.reload!

        names.zip(previous_classes).each do |name, previous_class|
          raise "#{name} did not reload" if name.constantize.equal?(previous_class)
        end
      end
    RUBY

    stdout, stderr, status =
      Open3.capture3(
        { "RAILS_ENV" => "test", "LOAD_PLUGINS" => "1", "SKIP_DB_AND_REDIS" => "1" },
        RbConfig.ruby,
        "-e",
        script,
        chdir: Rails.root.to_s,
      )

    expect(status.success?).to eq(true), "Reload subprocess failed:\n#{stdout}\n#{stderr}"
  end
end
