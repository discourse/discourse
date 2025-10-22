# frozen_string_literal: true

describe DiscourseAi::Translation::CategoryLocaleDetector do
  before { enable_current_plugin }

  describe ".detect_locale" do
    fab!(:category) do
      Fabricate(
        :category,
        name: "Hello world",
        description: "Welcome to this category",
        locale: nil,
      )
    end

    def language_detector_stub(opts)
      mock = instance_double(DiscourseAi::Translation::LanguageDetector)
      allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(
        opts[:text],
      ).and_return(mock)
      allow(mock).to receive(:detect).and_return(opts[:locale])
    end

    it "returns nil if category is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "updates the category locale with the detected locale" do
      text = "#{category.name}\n\n#{category.description}"
      language_detector_stub({ text: text, locale: "zh_CN" })

      expect { described_class.detect_locale(category) }.to change { category.reload.locale }.from(
        nil,
      ).to("zh_CN")
    end

    it "handles category with no description" do
      no_description_category =
        Fabricate(:category, name: "Test Category", description: nil, locale: nil)
      language_detector_stub({ text: no_description_category.name, locale: "fr" })

      expect { described_class.detect_locale(no_description_category) }.to change {
        no_description_category.reload.locale
      }.from(nil).to("fr")
    end

    it "bypasses validations when updating locale" do
      language_detector_stub(
        { text: "#{category.name}\n\n#{category.description}", locale: "zh_CN" },
      )

      described_class.detect_locale(category)
      expect(category.reload.locale).to eq("zh_CN")
    end
  end
end
