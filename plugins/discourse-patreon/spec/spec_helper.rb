# frozen_string_literal: true

module Helpers
  def get_patreon_response(filename)
    dest = "#{Rails.root}/tmp/spec/#{filename}"
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp("#{Rails.root}/plugins/discourse-patreon/spec/fixtures/#{filename}", dest)
    File.new(dest).read
  end
end

RSpec.configure { |config| config.include Helpers }
