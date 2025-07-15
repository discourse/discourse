# frozen_string_literal: true

RSpec.configure do |config|
  # this is so that fabricators can fabricate
  # since the creation of some models require
  # the plugin to be turned on
  SiteSetting.post_voting_enabled = true
end
