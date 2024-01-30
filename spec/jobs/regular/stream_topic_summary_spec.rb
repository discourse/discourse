# frozen_string_literal: true

RSpec.describe Jobs::StreamTopicSummary do
  subject(:job) { described_class.new }

  describe "#execute" do
    fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }
    let(:plugin) { Plugin::Instance.new }
    let(:strategy) { DummyCustomSummarization.new({ summary: "dummy", chunks: [] }) }
    fab!(:user) { Fabricate(:leader) }

    before { Group.find(Group::AUTO_GROUPS[:trust_level_3]).add(user) }

    before do
      plugin.register_summarization_strategy(strategy)
      SiteSetting.summarization_strategy = strategy.model
    end

    after { DiscoursePluginRegistry.reset_register!(:summarization_strategies) }

    describe "validates params" do
      it "does nothing if there is no topic" do
        messages =
          MessageBus.track_publish("/summaries/topic/#{topic.id}") do
            job.execute(topic_id: nil, user_id: user.id)
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no user" do
        messages =
          MessageBus.track_publish("/summaries/topic/#{topic.id}") do
            job.execute(topic_id: topic.id, user_id: nil)
          end

        expect(messages).to be_empty
      end

      it "does nothing if the user is not allowed to see the topic" do
        private_topic = Fabricate(:private_message_topic)

        messages =
          MessageBus.track_publish("/summaries/topic/#{private_topic.id}") do
            job.execute(topic_id: private_topic.id, user_id: user.id)
          end

        expect(messages).to be_empty
      end
    end

    it "publishes updates with a partial summary" do
      messages =
        MessageBus.track_publish("/summaries/topic/#{topic.id}") do
          job.execute(topic_id: topic.id, user_id: user.id)
        end

      partial_summary_update = messages.first.data
      expect(partial_summary_update[:done]).to eq(false)
      expect(partial_summary_update.dig(:topic_summary, :summarized_text)).to eq("dummy")
    end

    it "publishes a final update to signal we're done and provide metadata" do
      messages =
        MessageBus.track_publish("/summaries/topic/#{topic.id}") do
          job.execute(topic_id: topic.id, user_id: user.id)
        end

      final_update = messages.last.data
      expect(final_update[:done]).to eq(true)

      expect(final_update.dig(:topic_summary, :algorithm)).to eq(strategy.model)
      expect(final_update.dig(:topic_summary, :outdated)).to eq(false)
      expect(final_update.dig(:topic_summary, :can_regenerate)).to eq(true)
      expect(final_update.dig(:topic_summary, :new_posts_since_summary)).to be_zero
    end
  end
end
