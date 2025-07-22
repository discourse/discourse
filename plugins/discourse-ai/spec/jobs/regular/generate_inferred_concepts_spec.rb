# frozen_string_literal: true

RSpec.describe Jobs::GenerateInferredConcepts do
  fab!(:topic)
  fab!(:post)
  fab!(:concept) { Fabricate(:inferred_concept, name: "programming") }

  before do
    enable_current_plugin
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#execute" do
    it "does nothing with blank item_ids" do
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :match_topic_to_concepts,
      )

      subject.execute(item_type: "topics", item_ids: [])
      subject.execute(item_type: "topics", item_ids: nil)
    end

    it "does nothing with blank item_type" do
      expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
        :match_topic_to_concepts,
      )

      subject.execute(item_type: "", item_ids: [topic.id])
      subject.execute(item_type: nil, item_ids: [topic.id])
    end

    it "validates item_type to be topics or posts" do
      allow(Rails.logger).to receive(:error).with(/Invalid item_type/)

      subject.execute(item_type: "invalid", item_ids: [1])
    end

    context "with topics" do
      it "processes topics in match_only mode" do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :match_topic_to_concepts,
        ).with(topic)

        subject.execute(item_type: "topics", item_ids: [topic.id], match_only: true)
      end

      it "processes topics in generation mode" do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :generate_concepts_from_topic,
        ).with(topic)

        subject.execute(item_type: "topics", item_ids: [topic.id], match_only: false)
      end

      it "handles topics that don't exist" do
        # Non-existent IDs should be silently skipped (no error expected)
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
          :match_topic_to_concepts,
        )

        subject.execute(
          item_type: "topics",
          item_ids: [999_999], # non-existent ID
          match_only: true,
        )
      end

      it "processes multiple topics" do
        topic2 = Fabricate(:topic)

        manager_instance = instance_double(DiscourseAi::InferredConcepts::Manager)
        allow(DiscourseAi::InferredConcepts::Manager).to receive(:new).and_return(manager_instance)

        allow(manager_instance).to receive(:match_topic_to_concepts).with(topic)
        allow(manager_instance).to receive(:match_topic_to_concepts).with(topic2)

        subject.execute(item_type: "topics", item_ids: [topic.id, topic2.id], match_only: true)
      end

      it "processes topics in batches" do
        topics = Array.new(5) { Fabricate(:topic) }
        topic_ids = topics.map(&:id)

        # Should process in batches of 3
        allow(Topic).to receive(:where).with(id: topic_ids[0..2]).and_call_original
        allow(Topic).to receive(:where).with(id: topic_ids[3..4]).and_call_original

        subject.execute(item_type: "topics", item_ids: topic_ids, batch_size: 3, match_only: true)
      end
    end

    context "with posts" do
      it "processes posts in match_only mode" do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :match_post_to_concepts,
        ).with(post)

        subject.execute(item_type: "posts", item_ids: [post.id], match_only: true)
      end

      it "processes posts in generation mode" do
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
          :generate_concepts_from_post,
        ).with(post)

        subject.execute(item_type: "posts", item_ids: [post.id], match_only: false)
      end

      it "handles posts that don't exist" do
        # Non-existent IDs should be silently skipped (no error expected)
        expect_any_instance_of(DiscourseAi::InferredConcepts::Manager).not_to receive(
          :match_post_to_concepts,
        )

        subject.execute(
          item_type: "posts",
          item_ids: [999_999], # non-existent ID
          match_only: true,
        )
      end

      it "processes multiple posts" do
        post2 = Fabricate(:post)

        manager_instance = instance_double(DiscourseAi::InferredConcepts::Manager)
        allow(DiscourseAi::InferredConcepts::Manager).to receive(:new).and_return(manager_instance)

        allow(manager_instance).to receive(:match_post_to_concepts).with(post)
        allow(manager_instance).to receive(:match_post_to_concepts).with(post2)

        subject.execute(item_type: "posts", item_ids: [post.id, post2.id], match_only: true)
      end
    end

    it "handles exceptions during processing" do
      allow_any_instance_of(DiscourseAi::InferredConcepts::Manager).to receive(
        :match_topic_to_concepts,
      ).and_raise(StandardError.new("Test error"))

      allow(Rails.logger).to receive(:error).with(
        /Error generating concepts from topic #{topic.id}/,
      )

      subject.execute(item_type: "topics", item_ids: [topic.id], match_only: true)
    end

    it "uses default batch size of 100" do
      topics = Array.new(150) { Fabricate(:topic) }
      topic_ids = topics.map(&:id)

      # Should process in batches of 100
      allow(Topic).to receive(:where).with(id: topic_ids[0..99]).and_call_original
      allow(Topic).to receive(:where).with(id: topic_ids[100..149]).and_call_original

      subject.execute(item_type: "topics", item_ids: topic_ids, match_only: true)
    end

    it "respects custom batch size" do
      topics = Array.new(5) { Fabricate(:topic) }
      topic_ids = topics.map(&:id)

      # Should process in batches of 2
      allow(Topic).to receive(:where).with(id: topic_ids[0..1]).and_call_original
      allow(Topic).to receive(:where).with(id: topic_ids[2..3]).and_call_original
      allow(Topic).to receive(:where).with(id: topic_ids[4..4]).and_call_original

      subject.execute(item_type: "topics", item_ids: topic_ids, batch_size: 2, match_only: true)
    end
  end
end
