# frozen_string_literal: true

RSpec.describe RandomUsernameWordListValidator do
  subject(:validator) { described_class.new }

  it "accepts a list of username-safe words" do
    expect(validator.valid_value?("quiet|brisk|golden")).to eq(true)
  end

  it "rejects an empty list" do
    expect(validator.valid_value?("")).to eq(false)
  end

  it "rejects words that would be rewritten by username sanitization" do
    expect(validator.valid_value?("quiet falcon")).to eq(false)
    expect(validator.valid_value?("quiet|-falcon")).to eq(false)
  end

  it "is wired up to the word list settings" do
    expect { SiteSetting.random_username_adjectives = "quiet falcon" }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect { SiteSetting.random_username_nouns = "" }.to raise_error(Discourse::InvalidParameters)
  end

  it "rejects non-Latin words unless unicode usernames are enabled" do
    expect(validator.valid_value?("静か")).to eq(false)

    SiteSetting.unicode_usernames = true

    expect(validator.valid_value?("静か")).to eq(true)
  end
end
