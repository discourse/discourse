# frozen_string_literal: true

describe DiscourseAi::Translation::EntryPoint do
  before do
    enable_current_plugin
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "en"
  end

  describe "upon post process cooked" do
    it "enqueues detect post locale and translate post job" do
      post =
        PostCreator.create!(Fabricate(:user), raw: "post", title: "topic", skip_validations: true)
      expect_job_enqueued(job: :detect_translate_post, args: { post_id: post.id })
    end

    it "does not enqueue if setting disabled" do
      SiteSetting.ai_translation_enabled = false
      post = Fabricate(:post)
      CookedPostProcessor.new(post).post_process

      expect(job_enqueued?(job: :detect_translate_post, args: { post_id: post.id })).to eq false
    end
  end

  describe "upon topic created" do
    it "enqueues detect topic locale and translate topic job" do
      topic =
        PostCreator.create!(
          Fabricate(:admin),
          raw: "post",
          title: "topic",
          skip_validations: true,
        ).topic

      expect_job_enqueued(job: :detect_translate_topic, args: { topic_id: topic.id })
    end

    it "does not enqueue if setting disabled" do
      SiteSetting.ai_translation_enabled = false
      topic =
        PostCreator.create!(
          Fabricate(:admin),
          raw: "post",
          title: "topic",
          skip_validations: true,
        ).topic

      expect(job_enqueued?(job: :detect_translate_topic, args: { topic_id: topic.id })).to eq false
    end
  end

  describe "upon first post (topic) edited" do
    fab!(:post) { Fabricate(:post, post_number: 1) }
    fab!(:non_first_post) { Fabricate(:post, post_number: 2) }

    before do
      Fabricate(:fake_model).tap do |fake_llm|
        SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
      end
    end

    it "enqueues detect topic locale and translate topic job" do
      SiteSetting.ai_translation_enabled = true
      topic = post.topic
      revisor = PostRevisor.new(post, topic)
      revisor.revise!(
        post.user,
        { title: "A whole new hole" },
        { validate_post: false, bypass_bump: false },
      )
      revisor.post_process_post

      expect_job_enqueued(job: :detect_translate_topic, args: { topic_id: topic.id })
    end

    it "does not enqueue if setting disabled" do
      SiteSetting.ai_translation_enabled = false

      expect(
        job_enqueued?(job: :detect_translate_topic, args: { topic_id: post.topic_id }),
      ).to eq false
    end
  end
end
