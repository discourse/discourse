# frozen_string_literal: true

require 'rails_helper'

describe AdminUserListSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:guardian) { Guardian.new(admin) }

  let(:serializer) do
    AdminUserListSerializer.new(user, scope: guardian, root: false)
  end

  context "when totp enabled" do
    before do
      Fabricate(:user_second_factor_totp, user: user)
    end
    it "returns the right values" do
      json = serializer.as_json

      expect(json[:second_factor_enabled]).to eq(true)
    end
  end

  context "when security keys enabled" do
    before do
      Fabricate(:user_security_key, user: user)
    end
    it "returns the right values" do
      json = serializer.as_json

      expect(json[:second_factor_enabled]).to eq(true)
    end
  end

  context "emails" do
    fab!(:admin) { Fabricate(:user, admin: true, email: "admin@email.com") }
    fab!(:moderator) { Fabricate(:user, moderator: true, email: "moderator@email.com") }
    fab!(:user) { Fabricate(:user, email: "user@email.com") }

    def serialize(user, viewed_by, opts = nil)
      AdminUserListSerializer.new(
        user,
        scope: Guardian.new(viewed_by),
        root: false,
        emails_desired: opts && opts[:emails_desired]
      ).as_json
    end

    def fabricate_secondary_emails_for(u)
      Fabricate(:secondary_email, user: u, email: "first@email.com")
      Fabricate(:secondary_email, user: u, email: "second@email.com")
    end

    it "contains an admin's own emails" do
      fabricate_secondary_emails_for(admin)
      json = serialize(admin, admin)
      expect(json[:email]).to eq("admin@email.com")
      expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
    end

    it "doesn't include a regular user's emails" do
      fabricate_secondary_emails_for(user)
      json = serialize(user, user)
      expect(json[:email]).to eq(nil)
      expect(json[:secondary_emails]).to eq(nil)
    end

    it "doesn't return emails for a moderator request when moderators_view_emails is disabled" do
      SiteSetting.moderators_view_emails = false
      fabricate_secondary_emails_for(user)
      json = serialize(user, moderator, emails_desired: true)
      expect(json[:email]).to eq(nil)
      expect(json[:secondary_emails]).to eq(nil)
    end

    it "returns emails for a moderator request when moderators_view_emails is enabled" do
      SiteSetting.moderators_view_emails = true
      fabricate_secondary_emails_for(user)
      json = serialize(user, moderator, emails_desired: true)
      expect(json[:email]).to eq("user@email.com")
      expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
    end

    it "returns emails for admins when emails_desired is true" do
      fabricate_secondary_emails_for(user)
      json = serialize(user, admin, emails_desired: true)
      expect(json[:email]).to eq("user@email.com")
      expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
    end

    it "returns a staged user's emails" do
      user.staged = true
      fabricate_secondary_emails_for(user)
      json = serialize(user, admin)
      expect(json[:email]).to eq("user@email.com")
      expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
    end
  end
end
