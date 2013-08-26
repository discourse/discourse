require "spec_helper"

require "auth/authenticator"
require_dependency "auth/result"

describe "users/omniauth_callbacks/complete.html.erb" do

  let :rendered_data do
    returned = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])
  end

  it "renders auth info" do
    result = Auth::Result.new
    result.user = User.new

    assign(:data, result)

    render

    rendered_data["authenticated"].should eq(false)
    rendered_data["awaiting_activation"].should eq(false)
    rendered_data["awaiting_approval"].should eq(false)
  end

  it "renders cas data " do
    result = Auth::Result.new

    result.email = "xxx@xxx.com"
    result.authenticator_name = "CAS"

    assign(:data, result)

    render

    rendered_data["email"].should eq(result.email)
    # TODO this is a bit weird, the upcasing is confusing,
    #  clean it up throughout
    rendered_data["auth_provider"].should eq("Cas")
  end

end


