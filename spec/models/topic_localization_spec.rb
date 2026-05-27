# frozen_string_literal: true

describe TopicLocalization do
  describe "#update_excerpt" do
    fab!(:topic)
    fab!(:topic_localization) do
      Fabricate(:topic_localization, topic: topic, locale: "ja", title: "日本語タイトル")
    end

    it "updates excerpt from cooked content" do
      topic_localization.update_excerpt(cooked: "<p>これは投稿の内容です。</p>")

      expect(topic_localization.excerpt).to eq("これは投稿の内容です。")
    end

    it "does nothing when cooked is empty" do
      topic_localization.update_excerpt(cooked: "")
      expect(topic_localization.excerpt).to be_nil

      topic_localization.update_excerpt(cooked: nil)
      expect(topic_localization.excerpt).to be_nil
    end

    it "strips links and images from excerpt" do
      cooked = <<~HTML
        <p>Check out <a href="https://example.com">this link</a> and <img src="test.jpg"> this image.</p>
      HTML

      topic_localization.update_excerpt(cooked:)

      expect(topic_localization.excerpt).to eq("Check out this link and  this image.")
    end
  end
end
