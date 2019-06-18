# frozen_string_literal: true

require 'rails_helper'

describe ReplyByEmailEnabledValidator do

  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "only validates when enabling the setting" do
      expect(validator.valid_value?("f")).to eq(true)
    end

    it "returns false if reply_by_email_address is missing" do
      SiteSetting.expects(:reply_by_email_address).returns("")
      expect(validator.valid_value?("t")).to eq(false)
    end

    it "returns false if email polling is disabled" do
      SiteSetting.expects(:reply_by_email_address).returns("foo.%{reply_key}+42@bar.com")
      SiteSetting.expects(:email_polling_enabled?).returns(false)
      expect(validator.valid_value?("t")).to eq(false)
    end

    it "returns true when email polling is enabled and the reply_by_email_address is configured" do
      SiteSetting.expects(:reply_by_email_address).returns("foo.%{reply_key}+42@bar.com")
      SiteSetting.expects(:email_polling_enabled?).returns(true)
      expect(validator.valid_value?("t")).to eq(true)
    end

  end

end
