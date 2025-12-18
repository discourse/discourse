# frozen_string_literal: true

describe DiscourseAi::Translation::TagLocaleDetector do
  before { enable_current_plugin }

  describe ".detect_locale" do
    fab!(:tag) { Fabricate(:tag, name: "hello-world", description: "A test tag", locale: nil) }

    def language_detector_stub(opts)
      mock = instance_double(DiscourseAi::Translation::LanguageDetector)
      allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(
        opts[:text],
      ).and_return(mock)
      allow(mock).to receive(:detect).and_return(opts[:locale])
    end

    it "returns nil if tag is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "returns nil if detected locale is blank and does not update tag" do
      text = "#{tag.name}\n\n#{tag.description}"
      language_detector_stub({ text: text, locale: nil })

      expect(described_class.detect_locale(tag)).to eq(nil)
      expect { described_class.detect_locale(tag) }.not_to change { tag }
    end

    it "updates the tag locale with the detected locale" do
      text = "#{tag.name}\n\n#{tag.description}"
      language_detector_stub({ text: text, locale: "zh_CN" })

      expect { described_class.detect_locale(tag) }.to change { tag.reload.locale }.from(nil).to(
        "zh_CN",
      )
    end

    it "handles tag with no description" do
      no_description_tag = Fabricate(:tag, name: "test-tag", description: nil, locale: nil)
      language_detector_stub({ text: no_description_tag.name, locale: "fr" })

      expect { described_class.detect_locale(no_description_tag) }.to change {
        no_description_tag.reload.locale
      }.from(nil).to("fr")
    end

    it "bypasses validations when updating locale" do
      language_detector_stub({ text: "#{tag.name}\n\n#{tag.description}", locale: "zh_CN" })

      described_class.detect_locale(tag)
      expect(tag.reload.locale).to eq("zh_CN")
    end
  end
end
