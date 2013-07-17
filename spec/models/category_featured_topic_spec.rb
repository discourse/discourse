require 'spec_helper'

describe CategoryFeaturedTopic do

  it { should belong_to :category }
  it { should belong_to :topic }

  context 'feature_topics_for' do
    let(:user)           { Fabricate(:user) }
    let(:category)       { Fabricate(:category) }
    let!(:category_post) { PostCreator.create(user, raw: "I put this post in the category", title: "categorize THIS", category: category.id) }

    it "should feature topics for a secure category" do

      # so much dancing, I am thinking fixures make sense here.
      user.change_trust_level!(:basic)

      category.set_permissions(:trust_level_1 => :full)
      category.save

      uncategorized_post = PostCreator.create(user, raw: "this is my new post 123 post", title: "hello world")

      CategoryFeaturedTopic.feature_topics_for(category)
      CategoryFeaturedTopic.count.should == 1

    end

    it 'should not include invisible topics' do
      invisible_post = PostCreator.create(user, raw: "Don't look at this post because it's awful.", title: "not visible to anyone", category: category.id)
      invisible_post.topic.update_status('visible', false, Fabricate(:admin))
      CategoryFeaturedTopic.feature_topics_for(category)
      CategoryFeaturedTopic.count.should == 1
    end
  end

end

