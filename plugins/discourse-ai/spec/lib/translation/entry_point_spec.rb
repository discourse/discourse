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

  describe "upon enabling ai_translation_enabled" do
    before do
      SiteSetting.ai_translation_enabled = false
      SiteSetting.ai_translation_backfill_start_date = ""
    end

    it "sets the backfill start date to 5 days ago when it is at the default value" do
      freeze_time

      SiteSetting.ai_translation_enabled = true

      expect(SiteSetting.ai_translation_backfill_start_date).to eq(5.days.ago.utc.to_date.iso8601)
    end

    it "keeps an existing backfill start date" do
      SiteSetting.ai_translation_backfill_start_date = "2026-07-01"

      SiteSetting.ai_translation_enabled = true

      expect(SiteSetting.ai_translation_backfill_start_date).to eq("2026-07-01")
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

  describe "upon category updated" do
    it "enqueues category retranslation when the description changes" do
      SiteSetting.content_localization_supported_locales = "de|fr"
      category = Fabricate(:category_with_definition, locale: "en")

      category.update!(description: "An updated category description")

      expect_job_enqueued(
        job: :localize_categories,
        args: {
          category_id: category.id,
          fields: ["description"],
          limit: 1,
          force: true,
        },
      )
    end

    it "enqueues category retranslation when the name changes" do
      category = Fabricate(:category, locale: "en")

      category.update!(name: "A new category name")

      expect_job_enqueued(
        job: :localize_categories,
        args: {
          category_id: category.id,
          fields: ["name"],
          limit: 1,
          force: true,
        },
      )
    end

    it "does not enqueue category retranslation when another field changes" do
      category = Fabricate(:category, locale: "en")

      category.update!(color: "FF0000")

      expect(job_enqueued?(job: :localize_categories)).to eq(false)
    end
  end

  describe "upon tag updated" do
    it "enqueues tag retranslation when the description changes" do
      SiteSetting.content_localization_supported_locales = "de|fr"
      tag = Fabricate(:tag, locale: "en")

      tag.update!(description: "An updated tag description")

      expect_job_enqueued(
        job: :localize_tags,
        args: {
          tag_id: tag.id,
          fields: ["description"],
          limit: 1,
          force: true,
        },
      )
    end

    it "enqueues tag retranslation when the name changes" do
      tag = Fabricate(:tag, locale: "en")

      tag.update!(name: "a-new-tag-name")

      expect_job_enqueued(
        job: :localize_tags,
        args: {
          tag_id: tag.id,
          fields: ["name"],
          limit: 1,
          force: true,
        },
      )
    end

    it "does not enqueue tag retranslation when another field changes" do
      tag = Fabricate(:tag, locale: "en")

      tag.update!(staff_topic_count: 1)

      expect(job_enqueued?(job: :localize_tags)).to eq(false)
    end
  end
end
