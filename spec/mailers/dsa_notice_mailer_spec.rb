# frozen_string_literal: true

RSpec.describe DsaNoticeMailer do
  describe "#verification" do
    it "emails the verification code and its lifetime" do
      code = "012345"
      message = described_class.verification(email: "pat@example.com", code:)

      expect(message.to).to eq(["pat@example.com"])
      expect(message.subject).to include("Your report verification code")
      expect(message.body.decoded).to include(
        code,
        "30 minutes",
        "verify your email for reporting illegal content",
      )
      expect(message["X-Discourse-Reply-Key"]).to be_nil
    end
  end

  describe "#receipt" do
    let(:notice) do
      Dsa::Notice.new(
        {
          "id" => 123,
          "content_url" => "https://example.com/post?a=1&b=2",
          "explanation" =>
            "This listing advertises counterfeit goods as authentic and deceives buyers.",
          "name" => "Pat O'Brien",
          "email" => "pat@example.com",
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
      expect(fragment.css("strong").map(&:text)).to eq(
        [
          "Report reference: #{notice.reference}",
          "Email address:",
          "Full name or organization name:",
          "Exact URL of the content:",
          "Why do you believe this content is illegal?",
          "Declaration:",
        ],
      )
      expect(fragment.text.scan(notice.reference).length).to eq(1)
      expect(message.text_part.decoded.scan(notice.reference).length).to eq(1)
      expect(fragment.at_css('a[href^="https://example.com/"]')["href"]).to eq(
        "https://example.com/post?a=1&b=2",
      )
      expect(message["X-Discourse-Reply-Key"]).to be_nil
    end
  end
end
