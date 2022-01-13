# frozen_string_literal: true
require 'rails_helper'

describe Auth::Result do
  fab!(:initial_email) { "initialemail@example.org" }
  fab!(:initial_username) { "initialusername" }
  fab!(:initial_name) { "Initial Name" }
  fab!(:user) { Fabricate(:user, email: initial_email, username: initial_username, name: initial_name) }

  let(:new_email) { "newemail@example.org" }
  let(:new_username) { "newusername" }
  let(:new_name) { "New Name" }

  let(:result) do
    result = Auth::Result.new
    result.email = new_email
    result.username = new_username
    result.name = new_name
    result.user = user
    result.email_valid = true
    result
  end

  it "doesn't override user attributes by default" do
    result.apply_user_attributes!
    expect(user.email).to eq(initial_email)
    expect(user.username).to eq(initial_username)
    expect(user.name).to eq(initial_name)
  end

  it "overrides user attributes when site settings enabled" do
    SiteSetting.email_editable = false
    SiteSetting.auth_overrides_email = true
    SiteSetting.auth_overrides_name = true
    SiteSetting.auth_overrides_username = true

    result.apply_user_attributes!

    expect(user.email).to eq(new_email)
    expect(user.username).to eq(new_username)
    expect(user.name).to eq(new_name)
  end

  it "overrides user attributes when result attributes set" do
    result.overrides_email = true
    result.overrides_name = true
    result.overrides_username = true

    result.apply_user_attributes!

    expect(user.email).to eq(new_email)
    expect(user.username).to eq(new_username)
    expect(user.name).to eq(new_name)
  end

  it "updates the user's email if currently invalid" do
    user.update!(email: "someemail@discourse.org")
    expect { result.apply_user_attributes! }.not_to change { user.email }

    user.update!(email: "someemail@discourse.invalid")
    expect { result.apply_user_attributes! }.to change { user.email }

    expect(user.email).to eq(new_email)
  end
end
