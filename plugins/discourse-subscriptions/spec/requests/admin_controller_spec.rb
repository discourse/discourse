# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSubscriptions::AdminController do
  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
    SiteSetting.discourse_subscriptions_enabled = true
  end

  it "is a subclass of AdminController" do
    expect(DiscourseSubscriptions::AdminController < ::Admin::AdminController).to eq(true)
  end

  it "is ok" do
    get "/s/admin.json"
    expect(response.status).to eq(200)
  end
end
