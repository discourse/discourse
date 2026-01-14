# frozen_string_literal: true

RSpec.describe "Core features", type: :system do
  before do
    SiteSetting.login_with_amazon_client_id = "somekey"
    SiteSetting.login_with_amazon_client_secret = "somesecretkey"
    enable_current_plugin
  end

  it_behaves_like "having working core features"
end
