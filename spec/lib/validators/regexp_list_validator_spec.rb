# frozen_string_literal: true

RSpec.describe RegexpListValidator do
  subject(:validator) { described_class.new }

  it "allows lists of valid regular expressions" do
    expect(validator.valid_value?('\d+|[0-9]?|\w+')).to eq(true)
  end

  it "does not allow lists of invalid regular expressions do" do
    expect(validator.valid_value?('\d+|[0-9?|\w+')).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t(
        "site_settings.errors.invalid_regex_with_message",
        regex: "[0-9?",
        message: "premature end of char-class: /[0-9?/",
      ),
    )
  end
end
