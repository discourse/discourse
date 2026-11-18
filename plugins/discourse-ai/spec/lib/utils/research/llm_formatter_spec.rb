# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::Research::LlmFormatter do
  fab!(:user) { Fabricate(:user, username: "test_user") }
  fab!(:topic) { Fabricate(:topic, title: "This is a Test Topic", user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:tokenizer) { DiscourseAi::Tokenizer::OpenAiTokenizer }
  let(:filter) { PostsFilter.new("username:#{user.username}") }

  before { enable_current_plugin }

  describe "#truncate_if_needed" do
    it "returns original content when under token limit" do
      formatter =
        described_class.new(
          filter,
          max_tokens_per_batch: 1000,
          tokenizer: tokenizer,
          max_tokens_per_post: 100,
        )

      short_text = "This is a short post"
      expect(formatter.send(:truncate_if_needed, short_text)).to eq(short_text)
    end

    it "truncates content when over token limit" do
      # Create a post with content that will exceed our token limit
      long_text = ("word " * 200).strip

      formatter =
        described_class.new(
          filter,
          max_tokens_per_batch: 1000,
          tokenizer: tokenizer,
          max_tokens_per_post: 50,
        )

      truncated = formatter.send(:truncate_if_needed, long_text)

      expect(truncated).to include("... elided 150 tokens ...")
      expect(truncated).to_not eq(long_text)

      # Should have roughly 25 words before and 25 after (half of max_tokens_per_post)
      first_chunk = truncated.split("\n\n")[0]
      expect(first_chunk.split(" ").length).to be_within(5).of(25)

      last_chunk = truncated.split("\n\n")[2]
      expect(last_chunk.split(" ").length).to be_within(5).of(25)
    end
  end

  describe "#format_post" do
    it "formats posts with truncation for long content" do
      # Set up a post with long content
      long_content = ("word " * 200).strip
      long_post = Fabricate(:post, raw: long_content, topic: topic, user: user)

      formatter =
        described_class.new(
          filter,
          max_tokens_per_batch: 1000,
          tokenizer: tokenizer,
          max_tokens_per_post: 50,
        )

      formatted = formatter.send(:format_post, long_post)

      # Should have standard formatting elements
      expect(formatted).to include("## Post by #{user.username}")
      expect(formatted).to include("Post url: /t/-/#{long_post.topic_id}/#{long_post.post_number}")

      # Should include truncation marker
      expect(formatted).to include("... elided 150 tokens ...")
    end
  end

  describe "#each_chunk" do
    subject(:listed_tag_names) { research_text[/^Tags: (.*)$/, 1].to_s.split(", ") }

    fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
    fab!(:public_tag) { Fabricate(:tag, name: "public-tag") }
    fab!(:staff_tag) { Fabricate(:tag, name: "staff-tag") }
    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [staff_tag.name])
    end

    let(:formatter) do
      described_class.new(
        filter,
        max_tokens_per_batch: 1000,
        tokenizer: tokenizer,
        max_tokens_per_post: 100,
        guardian: guardian,
      )
    end
    let(:guardian) { nil }
    let(:research_text) { formatter.to_enum(:each_chunk).map { |chunk| chunk[:text] }.join }

    before { topic.tags = [public_tag, staff_tag] }

    it "lists the tags that an anonymous user can see" do
      expect(listed_tag_names).to contain_exactly(public_tag.name)
    end

    context "when an anonymous user cannot see any tag of the topic" do
      before { topic.tags = [staff_tag] }

      it "omits the tags line" do
        expect(research_text).not_to include("Tags:")
      end
    end

    context "when the guardian can see a restricted tag of the topic" do
      let(:guardian) { moderator.guardian }

      it "lists the restricted tag" do
        expect(listed_tag_names).to contain_exactly(public_tag.name, staff_tag.name)
      end
    end

    context "when the guardian cannot see a restricted tag of the topic" do
      let(:guardian) { user.guardian }

      it "lists the visible tags only" do
        expect(listed_tag_names).to contain_exactly(public_tag.name)
      end
    end

    context "when tagging is disabled" do
      before { SiteSetting.tagging_enabled = false }

      it "omits the tags line" do
        expect(research_text).not_to include("Tags:")
      end
    end
  end
end
