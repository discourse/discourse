# frozen_string_literal: true

RSpec.describe Jobs::RecalculateNestedHotScores do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute
    described_class.new.execute(nil)
  end

  def set_hot_score_inputs(post, created_at:, like_score: 0)
    post.update_columns(
      created_at: created_at,
      like_score: like_score,
      reply_count: 0,
      incoming_link_count: 0,
      bookmark_count: 0,
      reads: 0,
    )
  end

  it "does nothing when nested replies are disabled" do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedViewPostStat.delete_all
    SiteSetting.nested_replies_enabled = false

    execute

    expect(NestedViewPostStat.find_by(post_id: post.id)).to be_nil
  end

  it "recalculates missing hot score stats", :aggregate_failures do
    old_created_at = Time.zone.at(0)
    recent_created_at = Time.zone.local(2026, 6, 1)
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    set_hot_score_inputs(parent, created_at: old_created_at)
    set_hot_score_inputs(child, created_at: recent_created_at, like_score: 100)
    NestedViewPostStat.delete_all

    execute

    parent_stat = NestedViewPostStat.find_by!(post: parent)
    child_stat = NestedViewPostStat.find_by!(post: child)
    expect(child_stat.hot_score_updated_at).to be_present
    expect(parent_stat.thread_hot_score).to be > parent_stat.hot_score
  end

  it "recalculates stale propagated hot scores", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    stat = NestedViewPostStat.find_by!(post: post)
    stat.update!(
      hot_score: 10.0,
      thread_hot_score: 0.0,
      relative_hot_score: 2.0,
      relative_thread_hot_score: 0.0,
      hot_score_updated_at: Time.current,
    )

    execute

    stat.reload
    expect(stat.thread_hot_score).to be > 0
    expect(stat.relative_thread_hot_score).to be > 0
  end

  it "groups topic-level and OP replies together", :aggregate_failures do
    cold_created_at = Time.zone.local(2026, 5, 1)
    hot_created_at = Time.zone.local(2026, 6, 1)
    cold_posts =
      11.times.map do
        Fabricate(:post, topic: topic, reply_to_post_number: nil).tap do |post|
          set_hot_score_inputs(post, created_at: cold_created_at)
        end
      end
    hot_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    set_hot_score_inputs(hot_post, created_at: hot_created_at, like_score: 100)
    NestedViewPostStat.delete_all

    execute

    cold_stat = NestedViewPostStat.find_by!(post: cold_posts.first)
    hot_stat = NestedViewPostStat.find_by!(post: hot_post)
    expect(hot_stat.relative_hot_score).to be >
      NestedReplies::HotScoreCalculator::RELATIVE_HOT_SCORE_BASELINE
    expect(hot_stat.relative_hot_score).to be > cold_stat.relative_hot_score
  end
end
