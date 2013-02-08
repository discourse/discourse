require "spec_helper"

describe "twitter/complete.html.erb" do
  it "renders data " do
    assign(:data, {:username =>"username", :auth_provider=>"Twitter", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("Twitter")
    rendered_data["awaiting_activation"].should eq(true)
  end
end
