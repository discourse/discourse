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

  describe ".create_with_post!" do
    fab!(:group)

    it "stores the original notice independently of the PM text" do
      attributes[:name] = "Alex\u00a0Morgan"
      attributes[:explanation] += "\nEvidence\u2002copied\u202ffrom\u3000a listing."

      created_notice = described_class.create_with_post!(attributes:, group:)
      saved_notice = described_class.find_by!(submission_id: attributes[:submission_id])

      expect(saved_notice.post.id).to eq(created_notice.post.id)
      saved_notice.post.update!(raw: "Staff edited this PM.")
      expect(saved_notice.reload.matches?(attributes)).to eq(true)
      expect(saved_notice.reference).to eq(created_notice.reference)
      expect(saved_notice.summary(plain_text: true)).to include(
        attributes[:name],
        attributes[:explanation],
      )
    end

    it "rolls back the PM when the notice cannot be stored" do
      described_class.create_with_post!(attributes:, group:)
      post_count = Post.count
      notice_count = described_class.count

      expect do described_class.create_with_post!(attributes:, group:) end.to raise_error(
        ActiveRecord::RecordNotUnique,
      )

      expect(Post.count).to eq(post_count)
      expect(described_class.count).to eq(notice_count)
    end
  end

  describe "#mark_group_notified!" do
    fab!(:group)

    it "records when group notifications were queued" do
      notice = described_class.create_with_post!(attributes:, group:)

      freeze_time do
        notice.mark_group_notified!

        expect(notice.reload.group_notified_at).to eq_time(Time.current)
        expect(notice).to be_group_notified
      end
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
    subject(:notice) { described_class.new(attributes) }

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
