# frozen_string_literal: true

describe DiscourseAi::Translation::TopicLocaleDetector do
  before { enable_current_plugin }

  describe ".detect_locale" do
    fab!(:topic) { Fabricate(:topic, title: "this is a cat topic", locale: nil) }
    fab!(:post) { Fabricate(:post, topic:) }

    def language_detector_stub(opts)
      mock = instance_double(DiscourseAi::Translation::LanguageDetector)
      allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(
        opts[:text],
        topic: opts[:topic],
      ).and_return(mock)
      allow(mock).to receive(:detect).and_return(opts[:locale])
    end

    it "returns nil if topic title is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "updates the topic locale with the detected locale" do
      language_detector_stub({ text: "This is a cat topic", locale: "zh_CN", topic: })
      expect { described_class.detect_locale(topic) }.to change { topic.reload.locale }.from(
        nil,
      ).to("zh_CN")
    end

    it "bypasses validations when updating locale" do
      topic.update_column(:title, "A")
      SiteSetting.min_topic_title_length = 15
      SiteSetting.max_topic_title_length = 16

      language_detector_stub({ text: "A", locale: "zh_CN", topic: })

      described_class.detect_locale(topic)
      expect(topic.reload.locale).to eq("zh_CN")
    end
  end
end
