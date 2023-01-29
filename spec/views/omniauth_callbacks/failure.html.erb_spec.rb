# frozen_string_literal: true

RSpec.describe "users/omniauth_callbacks/failure.html.erb" do
  before { flash[:error] = I18n.t("login.omniauth_error", strategy: "test") }

  it "renders the failure page" do
    render template: "users/omniauth_callbacks/failure"

    expect(rendered).to match I18n.t("login.omniauth_error.generic", strategy: "test")
  end
end
