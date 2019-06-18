# frozen_string_literal: true

require 'rails_helper'

describe CategoryFeaturedTopic do

  it { is_expected.to belong_to :category }
  it { is_expected.to belong_to :topic }

  context 'feature_topics_for' do
    fab!(:user)          { Fabricate(:user) }
    fab!(:category)      { Fabricate(:category) }
    let!(:category_post) { PostCreator.create(user, raw: "I put this post in the category", title: "categorize THIS", category: category.id) }

    it "works in batched mode" do
      category2 = Fabricate(:category)
      post2 = create_post(category: category2.id)

      CategoryFeaturedTopic.destroy_all
      CategoryFeaturedTopic.clear_batch!

      size = Category.order(:id).where('id < ?', category.id).count + 1

      CategoryFeaturedTopic.feature_topics(batched: true, batch_size: size)

      expect(CategoryFeaturedTopic.where(topic_id: category_post.topic_id).count).to eq(1)
      expect(CategoryFeaturedTopic.where(topic_id: post2.topic_id).count).to eq(0)

      CategoryFeaturedTopic.feature_topics(batched: true, batch_size: size)

      expect(CategoryFeaturedTopic.where(topic_id: post2.topic_id).count).to eq(1)
    end

    it "should feature topics for a secure category" do

      # so much dancing, I am thinking fixures make sense here.
      user.change_trust_level!(TrustLevel[1])

      category.set_permissions(trust_level_1: :full)
      category.save

      _uncategorized_post = PostCreator.create(user, raw: "this is my new post 123 post", title: "hello world")

      CategoryFeaturedTopic.feature_topics_for(category)
      expect(CategoryFeaturedTopic.count).to be(1)

    end

    it 'should not include invisible topics' do
      invisible_post = PostCreator.create(user, raw: "Don't look at this post because it's awful.", title: "not visible to anyone", category: category.id)
      invisible_post.topic.update_status('visible', false, Fabricate(:admin))
      CategoryFeaturedTopic.feature_topics_for(category)
      expect(CategoryFeaturedTopic.count).to be(1)
    end

    it 'should feature stuff in the correct order' do
      category = Fabricate(:category, num_featured_topics: 2)
      _t5 = Fabricate(:topic, category_id: category.id, bumped_at: 12.minutes.ago)
      t4 = Fabricate(:topic, category_id: category.id, bumped_at: 10.minutes.ago)
      t3 = Fabricate(:topic, category_id: category.id, bumped_at: 7.minutes.ago)
      t2 = Fabricate(:topic, category_id: category.id, bumped_at: 4.minutes.ago)
      t1 = Fabricate(:topic, category_id: category.id, bumped_at: 5.minutes.ago)
      pinned = Fabricate(:topic, category_id: category.id, pinned_at: 10.minutes.ago, bumped_at: 10.minutes.ago)

      CategoryFeaturedTopic.feature_topics_for(category)

      # Should find more than we need: pinned topics first, then num_featured_topics * 2
      expect(
        CategoryFeaturedTopic.where(category_id: category.id).order('rank asc').pluck(:topic_id)
      ).to eq([pinned.id, t2.id, t1.id, t3.id, t4.id])

    end
  end

end
