# frozen_string_literal: true

RSpec.describe DiscourseAi::Automation::LlmTagger do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:ai_persona)
  fab!(:llm_model)

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    ai_persona.update!(default_llm: llm_model)

    Fabricate(:tag, name: "bug")
    Fabricate(:tag, name: "feature")
    Fabricate(:tag, name: "question")
  end

  describe ".handle" do
    let(:available_tags) { %w[bug feature question] }

    before do
      Tag.find_by(name: "bug")&.update!(public_topic_count: 5)
      Tag.find_by(name: "feature")&.update!(public_topic_count: 3)
      Tag.find_by(name: "question")&.update!(public_topic_count: 1)
    end

    it "processes a post and applies appropriate tags" do
      mock_response = { "tags" => ["bug"], "confidence" => 0.9 }.to_json

      DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          available_tags: available_tags,
          confidence_threshold: 0.7,
          max_tags: 3,
          max_post_tokens: 4000,
        )
      end

      expect(topic.reload.tags.map(&:name)).to include("bug")
    end

    it "respects confidence threshold" do
      mock_response = { "tags" => ["bug"], "confidence" => 0.5 }.to_json

      DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          available_tags: available_tags,
          confidence_threshold: 0.7,
          max_tags: 3,
          max_post_tokens: 4000,
        )
      end

      expect(topic.reload.tags).to be_empty
    end

    it "filters out invalid tags" do
      mock_response = { "tags" => %w[bug invalid_tag], "confidence" => 0.9 }.to_json

      DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          available_tags: available_tags,
          confidence_threshold: 0.7,
          max_tags: 3,
          max_post_tokens: 4000,
        )
      end

      tags = topic.reload.tags.map(&:name)
      expect(tags).to include("bug")
      expect(tags).not_to include("invalid_tag")
    end

    it "respects max tags limit" do
      mock_response = { "tags" => %w[bug feature question extra], "confidence" => 0.9 }.to_json

      DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          available_tags: available_tags,
          confidence_threshold: 0.7,
          max_tags: 2,
          max_post_tokens: 4000,
        )
      end

      expect(topic.reload.tags.count).to eq(2)
    end

    it "handles malformed JSON gracefully" do
      allow(Rails.logger).to receive(:warn)

      DiscourseAi::Completions::Llm.with_prepared_responses(["invalid json"]) do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          available_tags: available_tags,
          confidence_threshold: 0.7,
          max_tags: 3,
          max_post_tokens: 4000,
        )
      end

      expect(Rails.logger).to have_received(:warn).with(/Failed to parse JSON response/)
      expect(topic.reload.tags).to be_empty
    end

    describe "discover mode" do
      it "processes a post using discover mode with all site tags" do
        mock_response = { "tags" => ["feature"], "confidence" => 0.8 }.to_json

        DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
          described_class.handle(
            post: post,
            tagger_persona_id: ai_persona.id,
            tag_mode: "discover",
            available_tags: [],
            confidence_threshold: 0.7,
            max_tags: 3,
            max_post_tokens: 4000,
          )
        end

        expect(topic.reload.tags.map(&:name)).to include("feature")
      end

      it "validates against all site tags in discover mode" do
        # Create an additional tag that's not in manual list
        Fabricate(:tag, name: "discovery", public_topic_count: 2)

        mock_response = { "tags" => ["discovery"], "confidence" => 0.8 }.to_json

        DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
          described_class.handle(
            post: post,
            tagger_persona_id: ai_persona.id,
            tag_mode: "discover",
            available_tags: %w[bug feature], # discovery tag not in this list
            confidence_threshold: 0.7,
            max_tags: 3,
            max_post_tokens: 4000,
          )
        end

        expect(topic.reload.tags.map(&:name)).to include("discovery")
      end

      it "filters out invalid tags in discover mode" do
        mock_response = { "tags" => %w[feature nonexistent_tag], "confidence" => 0.8 }.to_json

        DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
          described_class.handle(
            post: post,
            tagger_persona_id: ai_persona.id,
            tag_mode: "discover",
            available_tags: [],
            confidence_threshold: 0.7,
            max_tags: 3,
            max_post_tokens: 4000,
          )
        end

        tags = topic.reload.tags.map(&:name)
        expect(tags).to include("feature")
        expect(tags).not_to include("nonexistent_tag")
      end

      it "handles cache errors in discover mode" do
        allow(Rails.cache).to receive(:fetch).and_raise(StandardError.new("Cache error"))
        allow(Rails.logger).to receive(:warn)

        mock_response = { "tags" => ["bug"], "confidence" => 0.8 }.to_json

        DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
          described_class.handle(
            post: post,
            tagger_persona_id: ai_persona.id,
            tag_mode: "discover",
            available_tags: [],
            confidence_threshold: 0.7,
            max_tags: 3,
            max_post_tokens: 4000,
          )
        end

        expect(Rails.logger).to have_received(:warn).with(/Cache failed.*using direct query/)
        expect(topic.reload.tags.map(&:name)).to include("bug")
      end
    end

    describe "tag mode selection" do
      it "uses manual mode by default" do
        mock_response = { "tags" => ["bug"], "confidence" => 0.8 }.to_json

        DiscourseAi::Completions::Llm.with_prepared_responses([mock_response]) do
          described_class.handle(
            post: post,
            tagger_persona_id: ai_persona.id,
            available_tags: available_tags,
            confidence_threshold: 0.7,
            max_tags: 3,
            max_post_tokens: 4000,
          )
        end

        expect(topic.reload.tags.map(&:name)).to include("bug")
      end

      it "skips processing when manual mode has no available tags" do
        described_class.handle(
          post: post,
          tagger_persona_id: ai_persona.id,
          tag_mode: "manual",
          available_tags: [],
          confidence_threshold: 0.7,
          max_tags: 3,
          max_post_tokens: 4000,
        )

        expect(topic.reload.tags).to be_empty
      end
    end
  end
end
