# frozen_string_literal: true

RSpec.describe Jobs::GenerateConceptsFromPopularItems do
  subject(:job) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)
  fab!(:topic) { Fabricate(:topic, posts_count: 6, views: 150, like_count: 12) }
  fab!(:post) { Fabricate(:post, like_count: 8, post_number: 2) }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
    SiteSetting.inferred_concepts_daily_topics_limit = 20
    SiteSetting.inferred_concepts_daily_posts_limit = 30
    SiteSetting.inferred_concepts_min_posts = 5
    SiteSetting.inferred_concepts_min_likes = 10
    SiteSetting.inferred_concepts_min_views = 100
    SiteSetting.inferred_concepts_post_min_likes = 5
    SiteSetting.inferred_concepts_lookback_days = 30
  end

  describe "#execute" do
    it "does nothing when inferred_concepts_enabled is false" do
      SiteSetting.inferred_concepts_enabled = false

      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :find_candidate_topics,
      )
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :find_candidate_posts,
      )
      allow(Jobs).to receive(:enqueue)

      job.execute({})
    end

    it "does nothing when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false

      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :find_candidate_topics,
      )
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :find_candidate_posts,
      )

      job.execute({})
    end

    it "processes popular topics when enabled" do
      candidate_topics = [topic]

      freeze_time do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_topics,
        ).with(
          limit: 20,
          min_posts: 5,
          min_likes: 10,
          min_views: 100,
          created_after: 30.days.ago,
        ).and_return(candidate_topics)

        allow(Jobs).to receive(:enqueue).with(
          :generate_inferred_concepts,
          item_type: "topics",
          item_ids: [topic.id],
          batch_size: 10,
        )

        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_posts,
        ).and_return([])

        job.execute({})
      end
    end

    it "processes popular posts when enabled" do
      candidate_posts = [post]

      freeze_time do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_topics,
        ).and_return([])

        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_posts,
        ).with(
          limit: 30,
          min_likes: 5,
          exclude_first_posts: true,
          created_after: 30.days.ago,
        ).and_return(candidate_posts)

        allow(Jobs).to receive(:enqueue).with(
          :generate_inferred_concepts,
          item_type: "posts",
          item_ids: [post.id],
          batch_size: 10,
        )

        job.execute({})
      end
    end

    it "does not schedule jobs when no candidates found" do
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
        :find_candidate_topics,
      ).and_return([])
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
        :find_candidate_posts,
      ).and_return([])

      allow(Jobs).to receive(:enqueue)
      allow(Jobs).to receive(:enqueue_in)

      job.execute({})
    end

    it "uses site setting values for topic filtering" do
      SiteSetting.inferred_concepts_daily_topics_limit = 50
      SiteSetting.inferred_concepts_min_posts = 8
      SiteSetting.inferred_concepts_min_likes = 15
      SiteSetting.inferred_concepts_min_views = 200
      SiteSetting.inferred_concepts_lookback_days = 45

      freeze_time do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_topics,
        ).with(
          limit: 50,
          min_posts: 8,
          min_likes: 15,
          min_views: 200,
          created_after: 45.days.ago,
        ).and_return([])

        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_posts,
        ).and_return([])

        job.execute({})
      end
    end

    it "uses site setting values for post filtering" do
      SiteSetting.inferred_concepts_daily_posts_limit = 40
      SiteSetting.inferred_concepts_post_min_likes = 8
      SiteSetting.inferred_concepts_lookback_days = 45

      freeze_time do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_topics,
        ).and_return([])

        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :find_candidate_posts,
        ).with(
          limit: 40,
          min_likes: 8,
          exclude_first_posts: true,
          created_after: 45.days.ago,
        ).and_return([])

        job.execute({})
      end
    end

    it "skips querying when daily topic and post limits are 0" do
      SiteSetting.inferred_concepts_daily_topics_limit = 0
      SiteSetting.inferred_concepts_daily_posts_limit = 0
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:new)

      job.execute({})

      expect(DiscourseAi::InferredConcepts::Manager).not_to have_received(:new)
      expect(Jobs::GenerateInferredConcepts.jobs).to be_empty
    end

    it "processes both topics and posts in the same run" do
      candidate_topics = [topic]
      candidate_posts = [post]

      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
        :find_candidate_topics,
      ).and_return(candidate_topics)
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
        :find_candidate_posts,
      ).and_return(candidate_posts)

      allow(Jobs).to receive(:enqueue).twice

      job.execute({})
    end
  end

  context "when scheduling the job" do
    it "is scheduled to run daily" do
      expect(described_class.every).to eq(1.day)
    end
  end
end
