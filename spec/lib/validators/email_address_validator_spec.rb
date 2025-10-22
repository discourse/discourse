# frozen_string_literal: true

RSpec.describe EmailAddressValidator do
  it "should match valid emails" do
    [
      "test@discourse.org",
      "good_user@discourse.org",
      "incoming+%{reply_key}@discourse.org",
      "a" * 64 + "@" + "b" * 251 + ".com",
    ].each { |email| expect(EmailAddressValidator.valid_value?(email)).to eq(true) }
  end

  it "should not match invalid emails" do
    [
      "testdiscourse.org",
      "frank@invalid_host.contoso.com",
      "frank@invalid_host.com",
      "test@discourse.org; a@discourse.org",
      "random",
      "te=?utf-8?q?st?=@discourse.org",
      "",
      "test" * 100 + "@" + "test" * 100 + ".com",
    ].each { |email| expect(EmailAddressValidator.valid_value?(email)).to eq(false) }
  end
end
