# frozen_string_literal: true

RSpec.describe "Core features" do
  before do
    SiteSetting.cakeday_enabled = true
    SiteSetting.cakeday_birthday_enabled = true
  end

  it_behaves_like "having working core features"
end
