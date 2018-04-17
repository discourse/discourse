require 'rails_helper'

describe ReplyByEmailAddressValidator do

  describe '#valid_value?' do
    subject(:validator) { described_class.new }

    it "returns true for blank values" do
      expect(validator.valid_value?('')).to eq(true)
      expect(validator.valid_value?(nil)).to eq(true)
    end

    it "returns false if value is not an email address" do
      expect(validator.valid_value?('WAT%{reply_key}.com')).to eq(false)
      expect(validator.valid_value?('word +%{reply_key}@example.com')).to eq(false)
    end

    it "returns false if value does not contain '%{reply_key}'" do
      expect(validator.valid_value?('foo@bar.com')).to eq(false)
    end

    it "returns true if value does not contain '%{reply_key}' but 'find_related_post_with_key' is also disabled" do
      SiteSetting.expects(:find_related_post_with_key).returns(false)
      expect(validator.valid_value?('foo@bar.com')).to eq(true)
    end

    it "returns false if value is the same as SiteSetting.notification_email" do
      SiteSetting.expects(:notification_email).returns("foo@bar.com")
      expect(validator.valid_value?('foo+%{reply_key}@bar.com')).to eq(false)
    end

    it "returns true when value is OK" do
      SiteSetting.expects(:notification_email).returns("foo@bar.com")
      expect(validator.valid_value?('bar%{reply_key}@foo.com')).to eq(true)
    end

  end

end
