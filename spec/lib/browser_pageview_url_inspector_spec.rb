# frozen_string_literal: true

RSpec.describe BrowserPageviewUrlInspector do
  describe ".normalize" do
    it "returns a canonical site-relative path" do
      expect(
        described_class.normalize("https://forum.example/latest/?campaign=private#section"),
      ).to eq("/latest")
      expect(described_class.normalize("/top?token=private")).to eq("/top")
      expect(described_class.normalize("about/")).to eq("/about")
      expect(described_class.normalize("https://forum.example/")).to eq("/")
    end

    it "returns nil for an unusable URL" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("javascript:alert(1)")).to be_nil
    end
  end
end
