# frozen_string_literal: true

RSpec.describe TopTopic do
  describe "#sorted_periods" do
    context "when verifying enum sequence" do
      before { @sorted_periods = TopTopic.sorted_periods }

      it "'daily' should be at 1st position" do
        expect(@sorted_periods[:daily]).to eq(1)
      end

      it "'all' should be at 6th position" do
        expect(@sorted_periods[:all]).to eq(6)
      end
    end
  end

  it { is_expected.to belong_to :topic }

  describe ".refresh!" do
    fab!(:t1) { Fabricate(:topic) }
    fab!(:t2) { Fabricate(:topic) }

    it "begins blank" do
      expect(TopTopic.all).to be_blank
    end

    context "after calculating" do
      before { TopTopic.refresh! }

      it "should have top topics" do
        expect(TopTopic.pluck(:topic_id)).to match_array([t1.id, t2.id])
      end
    end
  end

  describe ".validate_period" do
    context "when passing a valid period" do
      it do
        expect { described_class.validate_period(described_class.periods.first) }.not_to raise_error
      end
    end

    context "when passing a blank value" do
      it do
        expect { described_class.validate_period(nil) }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when passing an invalid period" do
      it do
        expect { described_class.validate_period("bi-weekly") }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end

    context "when passing a non-string value" do
      it do
        expect { described_class.validate_period(ActionController::Parameters) }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end
  end

  describe "#compute_top_score_for" do
    fab!(:user)
    fab!(:coding_horror)

    fab!(:topic_1) { Fabricate(:topic, posts_count: 10, like_count: 28) }
    fab!(:t1_post_1) { Fabricate(:post, topic: topic_1, like_count: 28, post_number: 1) }

    fab!(:topic_2) { Fabricate(:topic, posts_count: 10, like_count: 20) }
    fab!(:t2_post_1) { Fabricate(:post, topic: topic_2, like_count: 10, post_number: 1) }
    fab!(:t2_post_2) { Fabricate(:post, topic: topic_2, like_count: 10) }

    fab!(:topic_3) { Fabricate(:topic, posts_count: 10) }
    fab!(:t3_post_1) { Fabricate(:post, topic_id: topic_3.id) }
    let!(:t3_view_1) { TopicViewItem.add(topic_3.id, "127.0.0.1", user) }
    let!(:t3_view_2) { TopicViewItem.add(topic_3.id, "127.0.0.2", coding_horror) }

    # Note: all topics has 10 posts so we can skip "0 - ((10 - topics.posts_count) / 20) * #{period}_op_likes_count" calculation

    it "should compute top score" do
      # Default Formula: log(views_count) * {2} + op_likes_count * {0.5} + LEAST(likes_count / posts_count, {3}) + 10 + log(posts_count)
      #
      # topic_1 => 0 + 14 + 3 + 10 + 0 => 27
      # topic_2 => 0 + 5 + 3 + 10 + 0.301029995664 => 18.301029995664
      # topic_3 => 0.602059991328 + 0 + 0 + 10 + 0 => 10.602059991328

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pick(:yearly_score)).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(10.602059991328)

      # when 'top_topics_formula_log_views_multiplier' setting is changed
      SiteSetting.top_topics_formula_log_views_multiplier = 4
      SiteSetting.top_topics_formula_first_post_likes_multiplier = 0.5 # unchanged
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier = 3 # unchanged

      # New Formula: log(views_count) * {4} + op_likes_count * {0.5} + LEAST(likes_count / posts_count, {3}) + 10 + log(posts_count)
      #
      # topic_1 => 0 + 14 + 3 + 10 + 0 => 27
      # topic_2 => 0 + 5 + 3 + 10 + 0.301029995664 => 18.301029995664
      # topic_3 => 1.2041199826559 + 0 + 0 + 10 + 0 => 11.2041199826559

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pick(:yearly_score)).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(11.2041199826559)

      # when 'top_topics_formula_first_post_likes_multiplier' setting is changed
      SiteSetting.top_topics_formula_log_views_multiplier = 2 # unchanged
      SiteSetting.top_topics_formula_first_post_likes_multiplier = 2
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier = 3 # unchanged

      # New Formula: log(views_count) * {2} + op_likes_count * {2} + LEAST(likes_count / posts_count, {3}) + 10 + log(posts_count)
      #
      # topic_1 => 0 + 56 + 3 + 10 + 0 => 69
      # topic_2 => 0 + 20 + 3 + 10 + 0.301029995664 => 33.301029995664
      # topic_3 => 0.602059991328 + 0 + 0 + 10 + 0 => 10.602059991328

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pick(:yearly_score)).to eq(69)
      expect(top_topics.where(topic_id: topic_2.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(33.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(10.602059991328)

      # when 'top_topics_formula_least_likes_per_post_multiplier' setting is changed
      SiteSetting.top_topics_formula_log_views_multiplier = 2 # unchanged
      SiteSetting.top_topics_formula_first_post_likes_multiplier = 0.5 # unchanged
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier = 6

      # New Formula: log(views_count) * {2} + op_likes_count * {0.5} + LEAST(likes_count / posts_count, {6}) + 10 + log(posts_count)
      #
      # topic_1 => 0 + 14 + 6 + 10 + 0 => 30
      # topic_2 => 0 + 5 + 6 + 10 + 0.301029995664 => 21.301029995664
      # topic_3 => 0.602059991328 + 0 + 0 + 10 + 0 => 10.602059991328

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pick(:yearly_score)).to eq(30)
      expect(top_topics.where(topic_id: topic_2.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(21.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(10.602059991328)

      # handles invalid string value
      SiteSetting.top_topics_formula_log_views_multiplier = "not good"
      SiteSetting.top_topics_formula_first_post_likes_multiplier = "not good"
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier = "not good"

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pick(:yearly_score)).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pick(:yearly_score)).to be_within(
        0.0000000001,
      ).of(10.602059991328)
    end

    it "triggers a DiscourseEvent for each refreshed period" do
      events = DiscourseEvent.track_events(:top_score_computed) { TopTopic.refresh! }
      periods = events.map { |e| e[:params].first[:period] }

      expect(periods).to match_array(%i[daily weekly monthly quarterly yearly all])
    end
  end
end
