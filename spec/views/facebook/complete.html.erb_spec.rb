require "spec_helper"

describe "facebook/complete.html.erb" do
  it "renders data " do
    assign(:data, {:username =>"username", :auth_provider=>"Facebook", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("Facebook")
    rendered_data["awaiting_activation"].should eq(true)
  end
end
