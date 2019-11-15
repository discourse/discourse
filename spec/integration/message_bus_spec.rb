# frozen_string_literal: true

require 'rails_helper'

describe 'message bus integration' do

  it "allows anonymous requests to the messagebus" do
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows authenticated requests to the messagebus" do
    sign_in Fabricate(:user)
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  context "with login_required" do
    before { SiteSetting.login_required = true }

    it "blocks anonymous requests to the messagebus" do
      post "/message-bus/poll"
      expect(response.status).to eq(403)
    end

    it "allows authenticated requests to the messagebus" do
      sign_in Fabricate(:user)
      post "/message-bus/poll"
      expect(response.status).to eq(200)
    end
  end

end
