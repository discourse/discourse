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
      stub_const(described_class, "ADJECTIVES", ["quiet"]) do
        stub_const(described_class, "NOUNS", ["falcon"]) do
          allow(described_class).to receive(:rand).and_return(42)
          Fabricate(:user, username: "QuietFalcon42")

          expect(described_class.generate).to eq("QuietFalcon421")
        end
      end
    end

    it "respects the site's maximum username length" do
      SiteSetting.max_username_length = 10

      expect(described_class.generate.length).to be <= 10
    end
  end
end
