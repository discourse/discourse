# frozen_string_literal: true

RSpec.describe PlaintextMentions do
  describe "#usernames" do
    it "treats Unicode whitespace and punctuation as mention boundaries" do
      content = "hi\u00A0@sam, @alex\u3000ok (@kim) mail@example.com x@lee"

      [false, true].each do |unicode_usernames|
        SiteSetting.unicode_usernames = unicode_usernames

        expect(described_class.new(content).usernames).to contain_exactly("sam", "alex", "kim")
      end
    end

    it "normalizes usernames the same way as stored usernames" do
      SiteSetting.unicode_usernames = true
      content = "@E\u0301le\u0300ve @\u00E9l\u00E8ve"

      expect(described_class.new(content).usernames).to eq(["\u00E9l\u00E8ve"])
    end
  end

  describe "#render" do
    it "links a decomposed Unicode mention to the stored username" do
      SiteSetting.unicode_usernames = true
      user = Fabricate(:user, username: "\u00E9l\u00E8ve")

      cooked = Nokogiri::HTML5.fragment(described_class.new("Ask @e\u0301le\u0300ve").render)

      expect(cooked.at_css("a.mention")["href"]).to eq(
        "/u/#{UrlHelper.encode_component(user.username_lower)}",
      )
    end
  end
end
