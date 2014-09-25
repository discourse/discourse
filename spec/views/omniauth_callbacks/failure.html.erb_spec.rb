require "spec_helper"

describe "users/omniauth_callbacks/failure.html.erb" do

    it "renders the failure page" do
        flash[:error] = I18n.t("login.omniauth_error", strategy: 'test')
        render

        rendered.match(I18n.t("login.omniauth_error", strategy: 'test')).should_not == nil
    end

end
