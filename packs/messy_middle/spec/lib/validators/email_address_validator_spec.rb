# frozen_string_literal: true

RSpec.describe EmailAddressValidator do
  it "should match valid emails" do
    %w[
      test@discourse.org
      good_user@discourse.org
      incoming+%{reply_key}@discourse.org
    ].each { |email| expect(EmailAddressValidator.valid_value?(email)).to eq(true) }
  end

  it "should not match invalid emails" do
    [
      "testdiscourse.org",
      "frank@invalid_host.contoso.com",
      "frank@invalid_host.com",
      "test@discourse.org; a@discourse.org",
      "random",
      "",
    ].each { |email| expect(EmailAddressValidator.valid_value?(email)).to eq(false) }
  end
end
