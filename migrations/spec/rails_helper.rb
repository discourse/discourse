# frozen_string_literal: true

# we need to require the rails_helper from core to load the Rails environment
require_relative "../../spec/rails_helper"

require "bundler/inline"
require "bundler/ui"

# this is a hack to allow us to load Gemfiles for converters
Dir[File.expand_path("../config/gemfiles/**/Gemfile", __dir__)].each do |path|
  # Create new UI and set level to confirm to avoid printing unnecessary messages
  bundler_ui = Bundler::UI::Shell.new
  bundler_ui.level = "confirm"

  gemfile(true, ui: bundler_ui) do
    # rubocop:disable Security/Eval
    eval(File.read(path), nil, path, 1)
    # rubocop:enable Security/Eval
  end
end
