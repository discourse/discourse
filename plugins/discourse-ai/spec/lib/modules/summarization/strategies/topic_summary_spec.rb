# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::TopicSummary do
  subject(:topic_summary) { described_class.new(topic) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 25) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  before { enable_current_plugin }

  describe "#targets_data" do
    shared_examples "includes only public-visible topics" do
      it "only includes visible posts" do
        post_2.update!(hidden: true)

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end

      it "doesn't include posts without users" do
        post_2.update!(user_id: nil)

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end

      it "doesn't include whispers" do
        post_2.update!(post_type: Post.types[:whisper])

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end
    end

    context "when the topic has a best replies summary" do
      before { topic.update(has_summary: true) }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic doesn't have a best replies summary" do
      before { topic.update(has_summary: false) }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic has embed content cached" do
      it "embed content is used instead of the raw text" do
        topic_embed =
          Fabricate(
            :topic_embed,
            topic: topic,
            embed_content_cache: "<p>hello world new post :D</p>",
          )

        content = topic_summary.targets_data
        op_content = content.first[:text]

        expect(op_content).to include(topic_embed.embed_content_cache)
      end
    end

    context "when enable_names enabled and prioritize_username_in_ux disabled" do
      fab!(:user) { Fabricate(:user, name: "test") }

      it "includes the name" do
        SiteSetting.enable_names = true
        SiteSetting.prioritize_username_in_ux = false

        post_1.update!(user: user)

        content = topic_summary.targets_data
        poster_name = content.first[:poster]

        expect(poster_name).to eq("test")
      end
    end

    context "when enable_names enabled and prioritize_username_in_ux enabled" do
      fab!(:user) { Fabricate(:user, username: "test") }

      it "includes the username" do
        SiteSetting.enable_names = true
        SiteSetting.prioritize_username_in_ux = true

        post_1.update!(user: user)

        content = topic_summary.targets_data
        poster_name = content.first[:poster]

        expect(poster_name).to eq("test")
      end
    end
  end

  describe "#as_llm_messages" do
    let(:contents) do
      [{ id: 1, poster: "user1", text: "First post content", last_version_at: Time.now }]
    end

    it "includes the topic title in the message" do
      topic.title = "Test Topic Title"

      messages = topic_summary.as_llm_messages(contents)
      content = messages.first[:content]

      expect(content).to include("The discussion title is: Test Topic Title")
    end

    context "when topic has a category" do
      fab!(:category) { Fabricate(:category, name: "Test Category") }

      it "includes the category name in the message" do
        topic.category = category

        messages = topic_summary.as_llm_messages(contents)
        content = messages.first[:content]

        expect(content).to include("Category: Test Category")
      end
    end

    context "when topic has tags" do
      fab!(:tag1) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }

      it "includes the tag names in the message" do
        topic.tags = [tag1, tag2]

        messages = topic_summary.as_llm_messages(contents)
        content = messages.first[:content]

        expect(content).to include("Tags: tag1, tag2")
      end

      context "with hidden tags" do
        fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }

        before do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
          topic.tags = [tag1, hidden_tag, tag2]
        end

        it "excludes hidden tags from summaries (summaries are cached and shared)" do
          # Summaries are cached and shared across all users, so hidden tags should never appear
          # regardless of who generates them
          messages = topic_summary.as_llm_messages(contents)
          content = messages.first[:content]

          expect(content).to include("Tags: tag1, tag2")
          expect(content).not_to include("hidden")
        end
      end
    end

    context "when topic has no category or tags" do
      it "doesn't include category or tags in the message" do
        topic.category = nil
        topic.tags = []

        messages = topic_summary.as_llm_messages(contents)
        content = messages.first[:content]

        expect(content).not_to include("Category:")
        expect(content).not_to include("Tags:")
      end
    end
  end
end
