# frozen_string_literal: true

require "rails_helper"

describe "users/omniauth_callbacks/failure.html.erb" do

  it "renders the failure page" do
    flash[:error] = I18n.t("login.omniauth_error", strategy: 'test')
      render

      expect(rendered.match(I18n.t("login.omniauth_error.generic", strategy: 'test'))).not_to eq(nil)
  end

end
