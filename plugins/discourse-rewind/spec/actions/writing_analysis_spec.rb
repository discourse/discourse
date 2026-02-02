# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::WritingAnalysis do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
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
    it "calculates total words correctly" do
      result = call_report

      expect(result[:data][:total_words]).to be > 0
      expect(result[:data][:total_words]).to eq(
        [post1, post2, post3].sum { |p| p.reload.word_count },
      )
    end

    it "calculates total posts correctly" do
      result = call_report

      expect(result[:data][:total_posts]).to eq(3)
    end

    it "calculates average post length correctly" do
      result = call_report

      total_words = [post1, post2, post3].sum { |p| p.reload.word_count }
      expected_avg = (total_words.to_f / 3).round(2)

      expect(result[:data][:average_post_length]).to eq(expected_avg)
    end

    it "calculates readability score" do
      result = call_report

      expect(result[:data][:readability_score]).to be_present
      expect(result[:data][:readability_score]).to be_a(Numeric)
    end

    it "returns correct identifier" do
      result = call_report

      expect(result[:identifier]).to eq("writing-analysis")
    end

    it "bounds readability score between 0 and 100" do
      result = call_report

      score = result[:data][:readability_score]
      expect(score).to be >= 0
      expect(score).to be <= 100
    end

    context "when user has posts with very long sentences" do
      fab!(:long_sentence_post) do
        Fabricate(
          :post,
          user: user,
          raw:
            "This is an extremely long sentence that goes on and on without any punctuation to break it up which would normally result in a very low readability score because readers generally find it difficult to follow sentences that contain too many clauses and ideas without pausing for breath or mental processing time",
          created_at: random_datetime,
        )
      end

      it "handles low readability scores" do
        result = call_report

        expect(result[:data][:readability_score]).to be >= 0
      end
    end

    context "when user has posts without punctuation" do
      fab!(:no_punctuation_post) do
        Fabricate(
          :post,
          user: user,
          raw: "Just some words without any sentence ending punctuation",
          created_at: random_datetime,
        )
      end

      it "treats posts as having at least one sentence" do
        result = call_report

        expect(result[:data][:readability_score]).to be_present
      end
    end

    context "when a post is deleted" do
      before { post1.trash!(Discourse.system_user) }

      it "does not include deleted posts in total posts" do
        result = call_report

        expect(result[:data][:total_posts]).to eq(2)
      end

      it "does not include deleted posts in total words" do
        result = call_report

        total_words = [post2, post3].sum { |p| p.reload.word_count }

        expect(result[:data][:total_words]).to eq(total_words)
      end

      it "does not include deleted posts in readability score calculation" do
        result_with_deletion = call_report

        post1.recover!
        result_without_deletion = call_report

        expect(result_with_deletion[:data][:readability_score]).not_to eq(
          result_without_deletion[:data][:readability_score],
        )
      end
    end

    context "when posts are from another user" do
      it "does not include other users' posts in total posts" do
        result = call_report

        expect(result[:data][:total_posts]).to eq(3)
      end

      it "does not include other users' posts in total words" do
        result = call_report

        expected_words = [post1, post2, post3].sum { |p| p.reload.word_count }

        expect(result[:data][:total_words]).to eq(expected_words)
      end
    end

    context "when user has no posts" do
      fab!(:user_with_no_posts, :user)
      fab!(:date) { Date.new(2021).all_year }

      it "returns zero values gracefully" do
        result = described_class.call(user: user_with_no_posts, date: date, guardian: user.guardian)

        expect(result[:data][:total_words]).to be_nil
        expect(result[:data][:total_posts]).to eq(0)
        expect(result[:data][:average_post_length]).to eq(0)
      end
    end

    context "with posts containing HTML and markdown" do
      fab!(:formatted_post) do
        Fabricate(
          :post,
          user: user,
          raw:
            "**Bold text** and *italic text*. [A link](https://example.com) and some code `var x = 1;`",
          created_at: random_datetime,
        )
      end

      it "strips HTML from readability calculation" do
        result = call_report

        expect(result[:data][:readability_score]).to be_present
        expect(result[:data][:readability_score]).to be > 0
      end
    end
  end

  context "when in rails development mode" do
    before { Rails.env.stubs(:development?).returns(true) }

    it "returns fake data" do
      result = call_report

      expect(result[:identifier]).to eq("writing-analysis")
      expect(result[:data][:total_words]).to eq(45_230)
      expect(result[:data][:total_posts]).to eq(197)
      expect(result[:data][:average_post_length]).to eq(230)
      expect(result[:data][:readability_score]).to eq(65.4)
    end
  end
end
