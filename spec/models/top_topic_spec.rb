require 'rails_helper'

describe TopTopic do

  describe '#sorted_periods' do
    context "verify enum sequence" do
      before do
        @sorted_periods = TopTopic.sorted_periods
      end

      it "'daily' should be at 1st position" do
        expect(@sorted_periods[:daily]).to eq(1)
      end

      it "'all' should be at 6th position" do
        expect(@sorted_periods[:all]).to eq(6)
      end
    end
  end

  it { is_expected.to belong_to :topic }

  context "refresh!" do

    let!(:t1) { Fabricate(:topic) }
    let!(:t2) { Fabricate(:topic) }

    it "begins blank" do
      expect(TopTopic.all).to be_blank
    end

    context "after calculating" do

      before do
        TopTopic.refresh!
      end

      it "should have top topics" do
        expect(TopTopic.pluck(:topic_id)).to match_array([t1.id, t2.id])
      end
    end
  end

  describe "#compute_top_score_for" do

    let(:user) { Fabricate(:user) }
    let(:coding_horror) { Fabricate(:coding_horror) }

    let!(:topic_1) { Fabricate(:topic, posts_count: 10, like_count: 28) }
    let!(:t1_post_1) { Fabricate(:post, topic: topic_1, like_count: 28, post_number: 1) }

    let!(:topic_2) { Fabricate(:topic, posts_count: 10, like_count: 20) }
    let!(:t2_post_1) { Fabricate(:post, topic: topic_2, like_count: 10, post_number: 1) }
    let!(:t2_post_2) { Fabricate(:post, topic: topic_2, like_count: 10) }

    let!(:topic_3) { Fabricate(:topic, posts_count: 10) }
    let!(:t3_post_1) { Fabricate(:post, topic_id: topic_3.id) }
    let!(:t3_view_1) { TopicViewItem.add(topic_3.id, '127.0.0.1', user) }
    let!(:t3_view_2) { TopicViewItem.add(topic_3.id, '127.0.0.2', coding_horror) }

    # Note: all topics has 10 posts so we can skip "0 - ((10 - topics.posts_count) / 20) * #{period}_op_likes_count" calculation

    it "should compute top score" do
      # Default Formula: log(views_count) * {2} + op_likes_count * {0.5} + LEAST(likes_count / posts_count, {3}) + 10 + log(posts_count)
      #
      # topic_1 => 0 + 14 + 3 + 10 + 0 => 27
      # topic_2 => 0 + 5 + 3 + 10 + 0.301029995664 => 18.301029995664
      # topic_3 => 0.602059991328 + 0 + 0 + 10 + 0 => 10.602059991328

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pluck(:yearly_score).first).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pluck(:yearly_score).first).to eq(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pluck(:yearly_score).first).to eq(10.602059991328)

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

      expect(top_topics.where(topic_id: topic_1.id).pluck(:yearly_score).first).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pluck(:yearly_score).first).to eq(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pluck(:yearly_score).first).to eq(11.2041199826559)

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

      expect(top_topics.where(topic_id: topic_1.id).pluck(:yearly_score).first).to eq(69)
      expect(top_topics.where(topic_id: topic_2.id).pluck(:yearly_score).first).to eq(33.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pluck(:yearly_score).first).to eq(10.602059991328)

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

      expect(top_topics.where(topic_id: topic_1.id).pluck(:yearly_score).first).to eq(30)
      expect(top_topics.where(topic_id: topic_2.id).pluck(:yearly_score).first).to eq(21.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pluck(:yearly_score).first).to eq(10.602059991328)

      # handles invalid string value
      SiteSetting.top_topics_formula_log_views_multiplier = "not good"
      SiteSetting.top_topics_formula_first_post_likes_multiplier = "not good"
      SiteSetting.top_topics_formula_least_likes_per_post_multiplier = "not good"

      TopTopic.refresh!
      top_topics = TopTopic.all

      expect(top_topics.where(topic_id: topic_1.id).pluck(:yearly_score).first).to eq(27)
      expect(top_topics.where(topic_id: topic_2.id).pluck(:yearly_score).first).to eq(18.301029995664)
      expect(top_topics.where(topic_id: topic_3.id).pluck(:yearly_score).first).to eq(10.602059991328)

    end
  end
end
