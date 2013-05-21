require "spec_helper"

describe "users/omniauth_callbacks/complete.html.erb" do
  it "renders facebook data " do
    assign(:data, {username: "username", :auth_provider=> "Facebook", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("Facebook")
    rendered_data["awaiting_activation"].should eq(true)
  end

  it "renders twitter data " do
    assign(:data, {username: "username", :auth_provider=>"Twitter", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("Twitter")
    rendered_data["awaiting_activation"].should eq(true)
  end


  it "renders openid data " do
    assign(:data, {username: "username", :auth_provider=>"OpenId", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("OpenId")
    rendered_data["awaiting_activation"].should eq(true)
  end

  it "renders github data " do
    assign(:data, {username: "username", :auth_provider=>"Github", :awaiting_activation=>true})

    render

    rendered_data = JSON.parse(rendered.match(/window.opener.Discourse.authenticationComplete\((.*)\)/)[1])

    rendered_data["username"].should eq("username")
    rendered_data["auth_provider"].should eq("Github")
    rendered_data["awaiting_activation"].should eq(true)
  end

end


