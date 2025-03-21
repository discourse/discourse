# frozen_string_literal: true

RSpec.describe Admin::Config::CustomizeController do
  fab!(:admin)
  fab!(:component_1) { Fabricate(:theme, component: true) }
  fab!(:component_2) { Fabricate(:theme, component: true) }

  before { sign_in(admin) }

  describe "#components" do
    it "works" do
      get "/admin/config/customize/components.json", params: { status: "active" }
      pp response.body
      pp response.status
    end
  end
end
