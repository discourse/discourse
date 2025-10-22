# frozen_string_literal: true
#
describe DiscourseAi::Utils::Research::LlmFormatter do
  fab!(:user) { Fabricate(:user, username: "test_user") }
  fab!(:topic) { Fabricate(:topic, title: "This is a Test Topic", user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:tokenizer) { DiscourseAi::Tokenizer::OpenAiTokenizer }
  let(:filter) { DiscourseAi::Utils::Research::Filter.new("@#{user.username}") }

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
end
