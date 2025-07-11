# frozen_string_literal: true

module Helpers
  def get_patreon_response(filename)
    FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exist?("#{Rails.root}/tmp/spec")
    FileUtils.cp(
      "#{Rails.root}/plugins/discourse-patreon/spec/fixtures/#{filename}",
      "#{Rails.root}/tmp/spec/#{filename}",
    )
    File.new("#{Rails.root}/tmp/spec/#{filename}").read
  end
end

RSpec.configure { |config| config.include Helpers }
