# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::WritingAnalysis do
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:post1) do
    Fabricate(
      :post,
      user: user,
      raw: "This is a simple post. It has two sentences.",
      created_at: random_datetime,
    )
  end

  fab!(:post2) do
    Fabricate(
      :post,
      user: user,
      raw:
        "Here is another post with more content. It contains multiple sentences. This helps test the readability calculation.",
      created_at: random_datetime,
    )
  end

  fab!(:post3) do
    Fabricate(
      :post,
      user: user,
      raw:
        "A longer post with various sentence structures. Some are short. Others are quite a bit longer and contain more complex vocabulary and punctuation! Does this affect the score?",
      created_at: random_datetime,
    )
  end

  fab!(:other_user_post) do
    Fabricate(
      :post,
      user: other_user,
      raw: "This post is from another user and should not be included.",
      created_at: random_datetime,
    )
  end

  describe ".call" do
    it "returns nothing when there is too little writing to analyse" do
      expect(call_report).to be_nil
    end

    context "when above the minimum writing volume" do
      around do |example|
        stub_const(described_class, "MINIMUM_WORDS", 1) do
          stub_const(described_class, "MINIMUM_POSTS", 1) { example.run }
        end
      end

      it "returns the writing statistics" do
        expect(call_report[:data]).to match(
          total_words: 54,
          total_posts: 3,
          average_post_length: 18.0,
          readability_score: be_within(0.0001).of(78.3569),
        )
      end

      it "treats unpunctuated text as one sentence and never scores below zero" do
        writer = Fabricate(:user)
        Fabricate(:post, user: writer, raw: "word " * 90, created_at: random_datetime)

        report = described_class.call(user: writer, date:)

        expect(report[:data][:readability_score]).to eq(0)
      end

      it "ignores deleted posts, posts in deleted topics and other users' posts" do
        post1.trash!(Discourse.system_user)
        post2.topic.trash!(Discourse.system_user)
        report = call_report

        [post1, other_user_post].each(&:destroy!)
        post2.topic.destroy!

        expect(report).to eq(call_report)
        expect(report[:data][:total_posts]).to eq(1)
      end
    end
  end
end
