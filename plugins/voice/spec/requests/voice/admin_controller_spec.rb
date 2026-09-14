# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AdminController do
  fab!(:admin)

  before { SiteSetting.voice_enabled = true }

  describe "#index" do
    it "serves the external agents page on direct navigation" do
      sign_in(admin)

      get "/admin/plugins/voice/voice-agent-integrations"

      expect(response.status).to eq(200)
    end
  end
end
