require "rails_helper"

require "auth/authenticator"
require_dependency "auth/result"

describe "users/omniauth_callbacks/complete.html.erb" do

  let :rendered_data do
    JSON.parse(rendered.match(/var authResult = (.*);/)[1])
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
    # TODO this is a bit weird, the upcasing is confusing,
    #  clean it up throughout
    expect(rendered_data["auth_provider"]).to eq("Cas")
  end

end
