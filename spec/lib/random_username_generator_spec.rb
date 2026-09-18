# frozen_string_literal: true

RSpec.describe RandomUsernameGenerator do
  describe ".generate" do
    it "returns a valid, available username built from the word lists and a number" do
      username = described_class.generate

      expect(username).to match(/\A[A-Z][a-z]+[A-Z][a-z]+\d{2}\z/)
      expect(UsernameValidator.new(username).valid_format?).to eq(true)
      expect(User.username_available?(username)).to eq(true)
    end

    it "finds an available variant when the generated name is taken" do
      SiteSetting.random_username_adjectives = "quiet"
      SiteSetting.random_username_nouns = "falcon"
      allow(described_class).to receive(:rand).and_return(42)
      Fabricate(:user, username: "QuietFalcon42")

      expect(described_class.generate).to eq("QuietFalcon421")
    end

    it "builds names from the admin-configured word lists" do
      SiteSetting.random_username_adjectives = "brisk"
      SiteSetting.random_username_nouns = "otter"

      expect(described_class.generate).to match(/\ABriskOtter\d{2}\z/)
    end

    it "respects the site's maximum username length" do
      SiteSetting.max_username_length = 10

      expect(described_class.generate.length).to be <= 10
    end

    it "returns nil when the site has opted out" do
      SiteSetting.enable_random_usernames = false

      expect(described_class.generate).to be_nil
    end

    it "returns nil when the words can't survive username sanitization" do
      # Unicode words pass validation while unicode usernames are on, then stop
      # being usable once the site turns them off.
      SiteSetting.unicode_usernames = true
      SiteSetting.random_username_adjectives = "静か"
      SiteSetting.random_username_nouns = "隼"
      SiteSetting.unicode_usernames = false

      expect(described_class.generate).to be_nil
    end
  end
end
