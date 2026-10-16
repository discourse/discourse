# frozen_string_literal: true

RSpec.describe DsaNoticeMailer do
  describe "#receipt" do
    let(:notice) do
      Dsa::Notice.new(
        data: {
          "submission_id" => SecureRandom.uuid,
          "reference" => "DSA-1234567890ABCDEF",
          "content_url" => "https://example.com/post?a=1&b=2",
          "explanation" =>
            "This listing advertises counterfeit goods as authentic and deceives buyers.",
          "name" => "Pat O'Brien",
          "email" => "pat@example.com",
          "anonymous" => false,
          "declaration" => true,
        },
      )
    end

    it "addresses the reporter and renders the reference and submitted summary in both formats" do
      message = described_class.receipt(notice)

      expect(message.to).to eq([notice.email])
      expect(message.subject).to include(notice.reference)
      expect(message.text_part.decoded).to include(notice.summary(plain_text: true))
      fragment = Nokogiri::HTML5.fragment(message.html_part.decoded)
      expected_summary = Nokogiri::HTML5.fragment(PrettyText.cook(notice.summary))
      expect(fragment.text).to include(expected_summary.text)
      expect(fragment.at_css('a[href^="https://example.com/"]')["href"]).to eq(
        "https://example.com/post?a=1&b=2",
      )
      expect(message.text_part.decoded).not_to include(I18n.t("dsa_notice.staff_guidance"))
      expect(message.html_part.decoded).not_to include("<!-- dsa-notice:", "submission_id")
      expect(message["X-Discourse-Reply-Key"]).to be_nil
    end
  end
end
