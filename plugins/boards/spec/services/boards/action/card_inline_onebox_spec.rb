# frozen_string_literal: true

RSpec.describe Boards::Action::CardInlineOnebox do
  subject(:result) { described_class.call(title:) }

  before { enable_current_plugin }

  context "when the title contains only an HTTPS URL" do
    let(:url) { "https://github.com/discourse/discourse/pull/42462" }
    let(:title) { "  #{url}  " }

    it "returns the inline onebox data" do
      InlineOneboxer
        .expects(:lookup)
        .with(url, invalidate: true)
        .returns(
          url:,
          title: "FEATURE: Add ProseMirror tab support",
          css_class: "--gh-status-approved",
          ignored: "value",
        )

      expect(result).to eq(
        "url" => url,
        "title" => "FEATURE: Add ProseMirror tab support",
        "css_class" => "--gh-status-approved",
        "ignored" => "value",
      )
    end
  end

  context "when the title contains anything besides a URL" do
    let(:title) { "https://example.com extra text" }

    it "returns nil without looking up the title" do
      InlineOneboxer.expects(:lookup).never

      expect(result).to be_nil
    end
  end

  context "when the title has an unsupported URL scheme" do
    let(:title) { "http://example.com/insecure" }

    it "returns nil without looking up the title" do
      InlineOneboxer.expects(:lookup).never

      expect(result).to be_nil
    end
  end

  context "when the inline onebox has no title" do
    let(:title) { "https://example.com/no-title" }

    it "returns nil" do
      InlineOneboxer.expects(:lookup).with(title, invalidate: true).returns(url: title, title: nil)

      expect(result).to be_nil
    end
  end

  context "when lookup fails" do
    let(:title) { "https://example.com/failure" }

    it "returns nil" do
      InlineOneboxer
        .expects(:lookup)
        .with(title, invalidate: true)
        .raises(StandardError, "network failure")

      expect(result).to be_nil
    end
  end
end
