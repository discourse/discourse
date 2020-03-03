# frozen_string_literal: true
require 'rails_helper'

describe ThemeFlagHelper do
  fab!(:theme) { Fabricate(:theme).tap { |t| t.theme_flag_set.update!(serialize_topic_excerpts: true) } }

  it "defines a getter for flags" do
    tfh = ThemeFlagHelper.new(theme_ids: [theme.id])
    expect(tfh.serialize_topic_excerpts).to eq(true)
  end

  it "can extract theme ids from a request object" do
    request = Rack::Request.new({ resolved_theme_ids: [theme.id] })
    tfh = ThemeFlagHelper.new(request: request)
    expect(tfh.serialize_topic_excerpts).to eq(true)
  end
end
