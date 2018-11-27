require "rails_helper"

require "auth/authenticator"
require_dependency "auth/result"

describe "users/omniauth_callbacks/complete.html.erb" do

  let :rendered_data do
    JSON.parse(rendered.match(/data-auth-result="([^"]*)"/)[1].gsub('&quot;', '"'))
  end

  it "renders auth info" do
    result = Auth::Result.new
    result.user = User.new

    assign(:auth_result, result)

    render

    expect(rendered_data["authenticated"]).to eq(false)
    expect(rendered_data["awaiting_activation"]).to eq(false)
    expect(rendered_data["awaiting_approval"]).to eq(false)
  end

  it "renders cas data " do
    result = Auth::Result.new

    result.email = "xxx@xxx.com"
    result.authenticator_name = "CAS"

    assign(:auth_result, result)

    render

    expect(rendered_data["email"]).to eq(result.email)
    expect(rendered_data["auth_provider"]).to eq("CAS")
  end

end
