# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnableInviteOnlyValidator do
  subject { described_class.new }

  context "when sso is enabled" do
    before do
      SiteSetting.sso_url = "https://example.com/sso"
      SiteSetting.enable_sso = true
    end

    it "is valid when false" do
      expect(subject.valid_value?('f')).to eq(true)
    end

    it "is isn't value for true" do
      expect(subject.valid_value?('t')).to eq(false)
      expect(subject.error_message).to eq(I18n.t(
        'site_settings.errors.sso_invite_only'
      ))
    end
  end

  context "when sso isn't enabled" do
    it "is valid when true or false" do
      expect(subject.valid_value?('f')).to eq(true)
      expect(subject.valid_value?('t')).to eq(true)
    end
  end

end
