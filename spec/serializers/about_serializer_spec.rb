# frozen_string_literal: true

require 'rails_helper'

describe AboutSerializer do

  fab!(:user) { Fabricate(:user) }

  context "login_required is enabled" do
    before do
      SiteSetting.login_required = true
      SiteSetting.contact_url = "https://example.com/contact"
      SiteSetting.contact_email = "example@foobar.com"
    end

    it "contact details are hidden from anonymous users" do
      json = AboutSerializer.new(About.new(nil), scope: Guardian.new(nil), root: nil).as_json
      expect(json[:contact_url]).to eq(nil)
      expect(json[:contact_email]).to eq(nil)
    end

    it "contact details are visible to regular users" do
      json = AboutSerializer.new(About.new(user), scope: Guardian.new(user), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end
  end

  context "login_required is disabled" do
    before do
      SiteSetting.login_required = false
      SiteSetting.contact_url = "https://example.com/contact"
      SiteSetting.contact_email = "example@foobar.com"
    end

    it "contact details are visible to anonymous users" do
      json = AboutSerializer.new(About.new(nil), scope: Guardian.new(nil), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end

    it "contact details are visible to regular users" do
      json = AboutSerializer.new(About.new(user), scope: Guardian.new(user), root: nil).as_json
      expect(json[:contact_url]).to eq(SiteSetting.contact_url)
      expect(json[:contact_email]).to eq(SiteSetting.contact_email)
    end
  end
end
