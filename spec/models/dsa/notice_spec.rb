# frozen_string_literal: true

RSpec.describe Dsa::Notice do
  let(:attributes) do
    {
      content_url: "https://example.com/post?a=1&b=2",
      explanation: "This listing advertises counterfeit goods as authentic and deceives buyers.",
      name: "Pat O'Brien",
      email: "pat@example.com",
    }
  end

  describe ".create_with_post!" do
    fab!(:group)

    it "stores the original notice independently of the PM text" do
      attributes[:name] = "Alex\u00a0Morgan"
      attributes[:explanation] += "\nEvidence\u2002copied\u202ffrom\u3000a listing."

      created_notice = described_class.create_with_post!(attributes:, group:)
      saved_notice = described_class.find(created_notice.id)

      expect(saved_notice.post.id).to eq(created_notice.post.id)
      saved_notice.post.update!(raw: "Staff edited this PM.")
      expect(saved_notice.reload.attributes.symbolize_keys.slice(*attributes.keys)).to eq(
        attributes,
      )
      expect(saved_notice.reference).to eq("DSA-#{saved_notice.id}")
      expect(saved_notice.summary(plain_text: true)).to include(
        attributes[:name],
        attributes[:explanation],
      )
    end

    it "rolls back the notice when the PM cannot be stored" do
      PostCreator.stubs(:create!).raises(ActiveRecord::RecordNotSaved)
      notice_count = described_class.count

      expect do described_class.create_with_post!(attributes:, group:) end.to raise_error(
        ActiveRecord::RecordNotSaved,
      )

      expect(described_class.count).to eq(notice_count)
    end
  end

  describe "#mark_receipt_sent!" do
    fab!(:group)

    it "records when the receipt was sent" do
      notice = described_class.create_with_post!(attributes:, group:)

      freeze_time do
        notice.mark_receipt_sent!

        expect(notice.reload.receipt_sent_at).to eq_time(Time.current)
        expect(notice).to be_receipt_sent
      end
    end
  end

  describe "#summary" do
    subject(:notice) { described_class.new(attributes.merge(id: 123)) }

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
      expect(notice.summary(plain_text: true)).to include(
        attributes[:name],
        attributes[:explanation],
      )
    end
  end
end
