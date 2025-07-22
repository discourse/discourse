# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::HotTopicGists do
  subject(:gist) { described_class.new(topic) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 25) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  before { enable_current_plugin }

  describe "#targets_data" do
    it "respects the `hot_topics_recent_days` setting" do
      post_2.update(created_at: (SiteSetting.hot_topics_recent_days + 1).days.ago)
      Fabricate(:post, topic: topic, post_number: 3)

      post_numbers = gist.targets_data.map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1, 3)
    end

    it "only includes visible posts" do
      post_2.update!(hidden: true)

      post_numbers = gist.targets_data.map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    it "doesn't include posts without users" do
      post_2.update!(user_id: nil)

      post_numbers = gist.targets_data.map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    it "doesn't include whispers" do
      post_2.update!(post_type: Post.types[:whisper])

      post_numbers = gist.targets_data.map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    context "when the topic has embed content cached" do
      it "embed content is used instead of the raw text" do
        topic_embed =
          Fabricate(
            :topic_embed,
            topic: topic,
            embed_content_cache: "<p>hello world new post :D</p>",
          )

        content = gist.targets_data
        op_content = content.first[:text]

        expect(op_content).to include(topic_embed.embed_content_cache)
      end
    end
  end
end
