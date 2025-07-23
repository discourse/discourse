# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::DiffUtils::SafetyChecker do
  before { enable_current_plugin }

  describe "#safe?" do
    subject { described_class.new(text).safe? }

    context "with safe text" do
      let(:text) { "This is a simple safe text without issues." }

      it { is_expected.to eq(true) }

      context "with normal HTML tags" do
        let(:text) { "Here is <strong>bold</strong> and <em>italic</em> text." }
        it { is_expected.to eq(true) }
      end

      context "with balanced markdown and no partial emoji" do
        let(:text) { "This is **bold**, *italic*, and a smiley :smile:!" }
        it { is_expected.to eq(true) }
      end

      context "with balanced quote blocks" do
        let(:text) { "[quote]Quoted text[/quote]" }
        it { is_expected.to eq(true) }
      end

      context "with complete image markdown" do
        let(:text) { "![alt text](https://example.com/image.png)" }
        it { is_expected.to eq(true) }
      end
    end

    context "with unsafe text" do
      context "with unclosed markdown link" do
        let(:text) { "This is a [link(https://example.com)" }
        it { is_expected.to eq(false) }
      end

      context "with unclosed raw HTML tag" do
        let(:text) { "Text with <div unclosed tag" }
        it { is_expected.to eq(false) }
      end

      context "with trailing incomplete URL" do
        let(:text) { "Check this out https://example.com/something" } # no closing punctuation
        it { is_expected.to eq(false) }
      end

      context "with unclosed backticks" do
        let(:text) { "Here is some `inline code without closing" }
        it { is_expected.to eq(false) }
      end

      context "with unbalanced bold or italic markdown" do
        let(:text) { "This is *italic without closing" }
        it { is_expected.to eq(false) }
      end

      context "with incomplete image markdown" do
        let(:text) { "Image ![alt text](https://example.com/image.png" } # missing closing )
        it { is_expected.to eq(false) }
      end

      context "with unbalanced quote blocks" do
        let(:text) { "[quote]Unclosed quote block" }
        it { is_expected.to eq(false) }
      end

      context "with unclosed triple backticks" do
        let(:text) { "```code block without closing" }
        it { is_expected.to eq(false) }
      end

      context "with partial emoji" do
        let(:text) { "A partial emoji :smile" }
        it { is_expected.to eq(false) }
      end
    end
  end
end
