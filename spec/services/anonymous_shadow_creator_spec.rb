# frozen_string_literal: true

require 'rails_helper'

describe AnonymousShadowCreator do

  it "returns no shadow by default" do
    expect(AnonymousShadowCreator.get(Fabricate.build(:user))).to eq(nil)
  end

  context "Anonymous posting is enabled" do

    before { SiteSetting.allow_anonymous_posting = true }

    fab!(:user) { Fabricate(:user, trust_level: 3) }

    it "returns no shadow if trust level is not met" do
      expect(AnonymousShadowCreator.get(Fabricate.build(:user, trust_level: 0))).to eq(nil)
    end

    it "returns no shadow if must_approve_users is true and user is not approved" do
      SiteSetting.must_approve_users = true
      expect(AnonymousShadowCreator.get(Fabricate.build(:user, approved: false))).to eq(nil)
    end

    it "returns a new shadow once time expires" do
      SiteSetting.anonymous_account_duration_minutes = 1

      shadow = AnonymousShadowCreator.get(user)

      freeze_time 2.minutes.from_now
      shadow2 = AnonymousShadowCreator.get(user)

      expect(shadow.id).to eq(shadow2.id)
      create_post(user: shadow)

      user.reload
      shadow.reload

      freeze_time 4.minutes.from_now
      shadow3 = AnonymousShadowCreator.get(user)

      expect(shadow3.user_option.email_digests).to eq(false)
      expect(shadow3.user_option.email_messages_level).to eq(UserOption.email_level_types[:never])

      expect(shadow2.id).not_to eq(shadow3.id)

    end

    it "returns a shadow for a legit user" do
      shadow = AnonymousShadowCreator.get(user)
      shadow2 = AnonymousShadowCreator.get(user)

      expect(shadow.id).to eq(shadow2.id)

      expect(shadow.trust_level).to eq(1)
      expect(shadow.username).to eq("anonymous")

      expect(shadow.created_at).not_to eq_time(user.created_at)

      p = create_post

      expect(Guardian.new(shadow).post_can_act?(p, :like)).to eq(false)
      expect(Guardian.new(user).post_can_act?(p, :like)).to eq(true)

      expect(user.anonymous?).to eq(false)
      expect(shadow.anonymous?).to eq(true)
    end

    it "works even when names are required" do
      SiteSetting.full_name_required = true

      expect { AnonymousShadowCreator.get(user) }.to_not raise_error
    end

    it "works when there is an email allowlist" do
      SiteSetting.allowed_email_domains = "wayne.com"

      expect { AnonymousShadowCreator.get(user) }.to_not raise_error
    end

    it "falls back to username 'anonymous' if the translation for 'anonymous' consists entirely of disallowed characters" do
      # use russian locale but do not allow russian characters:
      I18n.locale = :ru
      SiteSetting.unicode_usernames = true
      SiteSetting.allowed_unicode_username_characters = "[äöü]"

      shadow = AnonymousShadowCreator.get(user)

      expect(shadow.username).to eq("anonymous")
    end
  end
end
