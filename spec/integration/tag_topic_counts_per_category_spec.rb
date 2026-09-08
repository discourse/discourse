# frozen_string_literal: true

RSpec.describe "tag topic counts per category" do
  fab!(:admin)
  fab!(:category)
  fab!(:category2, :category)
  fab!(:tag1, :tag)
  fab!(:tag2, :tag)
  fab!(:tag3, :tag)

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  it "counts when a topic is created with tags" do
    expect { Fabricate(:topic, category: category, tags: [tag1, tag2]) }.to change {
      CategoryTagStat.count
    }.by(2)
    expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
  end

  it "counts when tag is added to an existing topic" do
    user = Fabricate(:user, refresh_auto_groups: true)
    topic = Fabricate(:topic, user: user, category: category)
    post = Fabricate(:post, user: user, topic: topic)
    expect(CategoryTagStat.where(category: category).count).to eq(0)
    expect {
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [tag1.name, tag2.name])
    }.to change { CategoryTagStat.count }.by(2)
    expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
  end

  context "with a topic with two tags" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user, category: category, tags: [tag1, tag2]) }
    fab!(:post) { Fabricate(:post, user: user, topic: topic) }

    it "has correct counts after tag is removed from a topic" do
      post
      Fabricate(:topic, category: category, tags: [tag2])
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(2)
      PostRevisor.new(post).revise!(topic.user, raw: post.raw, tags: [])
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "has correct counts after a topic's category changes" do
      PostRevisor.new(post).revise!(
        topic.user,
        category_id: category2.id,
        raw: post.raw,
        tags: [tag1.name, tag2.name],
      )
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag1).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category2, tag: tag2).sum(:topic_count)).to eq(1)
    end

    it "has correct counts after the category and tags change" do
      PostRevisor.new(post).revise!(
        topic.user,
        raw: post.raw,
        tags: [tag2.name, tag3.name],
        category_id: category2.id,
      )
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag2).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category, tag: tag3).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag1).sum(:topic_count)).to eq(0)
      expect(CategoryTagStat.where(category: category2, tag: tag2).sum(:topic_count)).to eq(1)
      expect(CategoryTagStat.where(category: category2, tag: tag3).sum(:topic_count)).to eq(1)
    end
  end

  context "with a topic with one tag" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) { Fabricate(:topic, user: user, tags: [tag1], category: category) }
    fab!(:post) { Fabricate(:post, user: user, topic: topic) }

    it "counts after topic becomes uncategorized" do
      PostRevisor.new(post).revise!(
        user,
        raw: post.raw,
        tags: [tag1.name],
        category_id: SiteSetting.uncategorized_category_id,
      )
      expect(
        CategoryTagStat.where(
          category: Category.find(SiteSetting.uncategorized_category_id),
          tag: tag1,
        ).sum(:topic_count),
      ).to eq(1)
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "updates counts after topic is deleted" do
      PostDestroyer.new(admin, post).destroy
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(0)
    end

    it "updates counts after topic is recovered" do
      PostDestroyer.new(admin, post).destroy
      PostDestroyer.new(admin, post).recover
      expect(CategoryTagStat.where(category: category, tag: tag1).sum(:topic_count)).to eq(1)
    end
  end
end
