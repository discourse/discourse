# frozen_string_literal: true

require_relative "../../spec/rails_helper"

require "bundler/inline"
require "bundler/ui"

# this is a hack to allow us to load Gemfiles for converters
Dir[File.expand_path("../config/gemfiles/**/Gemfile", __dir__)].each do |path|
  gemfile(true) do
    # rubocop:disable Security/Eval
    eval(File.read(path), nil, path, 1)
    # rubocop:enable Security/Eval
  end
end
