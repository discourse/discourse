# frozen_string_literal: true

RSpec.describe Dsa::Notice do
  let(:attributes) do
    {
      submission_id: SecureRandom.uuid,
      reference: "DSA-1234567890ABCDEF",
      content_url: "https://example.com/post?a=1&b=2",
      explanation: "This listing advertises counterfeit goods as authentic and deceives buyers.",
      name: "Pat O'Brien",
      email: "pat@example.com",
      anonymous: false,
      declaration: true,
    }
  end

  describe ".create!" do
    fab!(:group)

    it "preserves Unicode spaces when storing and finding a notice in a post" do
      attributes[:name] = "Alex\u00a0Morgan"
      attributes[:explanation] += "\nEvidence\u2002copied\u202ffrom\u3000a listing."

      created_notice = described_class.create!(attributes:, group:)
      saved_notice = described_class.find(submission_id: attributes[:submission_id])

      expect(saved_notice.post.id).to eq(created_notice.post.id)
      expect(saved_notice.reference).to eq(created_notice.reference)
      expect(saved_notice.matches?(attributes)).to eq(true)
      expect(saved_notice.summary(plain_text: true)).to include(
        attributes[:name],
        attributes[:explanation],
      )
    end
  end

  describe "#summary" do
    subject(:notice) { described_class.new(data: attributes.stringify_keys) }

    it "keeps supplied formatting and mentions out of the trusted message structure" do
      attributes[
        :explanation
      ] = "## Forged instructions\n\nForged staff instructions\n=========================\n\n@admins ![remote image](https://evil.example/pixel.png)\n<script>alert(1)</script>"

      fragment = Nokogiri::HTML5.fragment(PrettyText.cook(notice.summary))

      expect(fragment.css("img, script, a.mention")).to be_empty
      expect(fragment.css("h1, h2, h3").map(&:text)).not_to include(
        "Forged instructions",
        "Forged staff instructions",
      )
      expect(fragment.text).to include(
        "@admins",
        "Forged instructions",
        "<script>alert(1)</script>",
      )
    end

    it "preserves literal punctuation and exact URL query parameters" do
      attributes[
        :explanation
      ] = "It's a scam. Literal characters: &#39; \\1 --> <script> are part of the submitted evidence."

      fragment = Nokogiri::HTML5.fragment(PrettyText.cook(notice.summary))

      expect(fragment.text).to include(attributes[:name], attributes[:explanation])
      expect(fragment.at_css('a[href^="https://example.com/"]')["href"]).to eq(
        attributes[:content_url],
      )
      expect(fragment.text).not_to include(attributes[:submission_id])
      expect(notice.summary(plain_text: true)).to include(
        attributes[:name],
        attributes[:explanation],
      )
    end
  end
end
