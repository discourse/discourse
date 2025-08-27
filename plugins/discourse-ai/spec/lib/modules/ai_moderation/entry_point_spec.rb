# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::EntryPoint do
  fab!(:post)
  fab!(:llm_model)

  before do
    enable_current_plugin

    AiModerationSetting.create!(
      setting_type: :spam,
      llm_model: llm_model,
      data: {
        custom_instructions: "test instructions",
      },
    )

    SiteSetting.ai_spam_detection_enabled = true
  end

  let(:custom_field_name) { DiscourseAi::AiModeration::SpamScanner::SHOULD_SCAN_POST_CUSTOM_FIELD }

  describe ":post_edited hooks" do
    it "does not queue edited post with no content changes" do
      category = Fabricate(:category)

      PostRevisor.new(post).revise!(post.user, category_id: category.id)

      expect(post.reload.custom_fields[custom_field_name]).not_to be_present
    end

    it "queues topic title edits" do
      PostRevisor.new(post).revise!(post.user, title: "#{post.topic.title} spam spam")

      expect(post.reload.custom_fields[custom_field_name]).to be_present
    end

    it "queues posts with raw changes" do
      PostRevisor.new(post).revise!(post.user, raw: "#{post.raw} spam spam")

      expect(post.reload.custom_fields[custom_field_name]).to be_present
    end
  end
end
