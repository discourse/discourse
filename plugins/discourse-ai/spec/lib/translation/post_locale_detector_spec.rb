# frozen_string_literal: true

describe DiscourseAi::Translation::PostLocaleDetector do
  before { enable_current_plugin }
  describe ".detect_locale" do
    fab!(:post) { Fabricate(:post, cooked: "Hello world", locale: nil) }

    def language_detector_stub(opts)
      mock = instance_double(DiscourseAi::Translation::LanguageDetector)
      allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(
        opts[:text],
        post: opts[:post],
      ).and_return(mock)
      allow(mock).to receive(:detect).and_return(opts[:locale])
    end

    it "returns nil if post is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "updates the post locale with the detected locale" do
      language_detector_stub({ text: post.cooked, locale: "zh_CN", post: })
      expect { described_class.detect_locale(post) }.to change { post.reload.locale }.from(nil).to(
        "zh_CN",
      )
    end

    it "returns site default locale if post is empty" do
      post.update_column(:cooked, "")
      expect { described_class.detect_locale(post) }.to change { post.reload.locale }.from(nil).to(
        "en",
      )
    end

    it "bypasses validations when updating locale" do
      post.update_column(:cooked, "A")

      language_detector_stub({ text: post.cooked, locale: "zh_CN", post: })

      described_class.detect_locale(post)
      expect(post.reload.locale).to eq("zh_CN")
    end
  end
end
