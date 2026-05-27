# frozen_string_literal: true

describe DiscourseAi::Translation::EntryPoint do
  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
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

  describe "upon topic edited" do
    fab!(:post) { Fabricate(:post, post_number: 1) }
    fab!(:non_first_post) { Fabricate(:post, post_number: 2) }

    before do
      enable_current_plugin
      assign_fake_provider_to(:ai_default_llm_model)
    end

    it "enqueues in grace period detect translate topic job if title changed" do
      freeze_time

      SiteSetting.editing_grace_period = 10.minutes
      SiteSetting.ai_translation_enabled = true
      topic = post.topic
      revisor = PostRevisor.new(post, topic)
      revisor.revise!(post.user, { title: "A whole new hole" }, { skip_validations: true })
      revisor.post_process_post

      expect_job_enqueued(
        job: :detect_translate_topic,
        args: {
          topic_id: topic.id,
        },
        at: 10.minutes.from_now,
      )
      expect(job_enqueued?(job: :detect_translate_post)).to eq false
    end

    it "enqueues in grace period detect translate topic job if first post (excerpt) changed" do
      freeze_time

      SiteSetting.editing_grace_period = 10.minutes
      SiteSetting.ai_translation_enabled = true
      topic = post.topic
      revisor = PostRevisor.new(post, topic)
      revisor.revise!(
        post.user,
        { raw: post.raw + " Additional content." },
        { skip_validations: true },
      )
      revisor.post_process_post

      expect_job_enqueued(
        job: :detect_translate_topic,
        args: {
          topic_id: topic.id,
        },
        at: 10.minutes.from_now,
      )
      expect(job_enqueued?(job: :detect_translate_post)).to eq true
    end

    it "does not enqueue detect translate topic job if title did not change" do
      new_category = Fabricate(:category)
      SiteSetting.ai_translation_enabled = true
      topic = post.topic
      post.revise(post.user, category_id: new_category.id)

      expect(job_enqueued?(job: :detect_translate_topic, args: { topic_id: topic.id })).to eq false
      expect(job_enqueued?(job: :detect_translate_post)).to eq false
    end

    it "does not enqueue if setting disabled" do
      SiteSetting.ai_translation_enabled = false

      expect(
        job_enqueued?(job: :detect_translate_topic, args: { topic_id: post.topic_id }),
      ).to eq false
      expect(job_enqueued?(job: :detect_translate_post)).to eq false
    end
  end

  describe "upon post edited" do
    it "enqueues detect translate post job in grace period" do
      freeze_time

      SiteSetting.editing_grace_period = 10.minutes
      SiteSetting.ai_translation_enabled = true
      post = Fabricate(:post, post_number: 2)
      post.revise(post.user, { raw: "new raw" })

      expect_job_enqueued(
        job: :detect_translate_post,
        args: {
          post_id: post.id,
        },
        at: 10.minutes.from_now,
      )
      expect(job_enqueued?(job: :detect_translate_topic)).to eq false
    end
  end
end
