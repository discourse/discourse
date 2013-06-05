require 'spec_helper'

describe CategoryFeaturedTopic do

  it { should belong_to :category }
  it { should belong_to :topic }

  it "should feature topics for a secure category" do

    # so much dancing, I am thinking fixures make sense here.
    user = Fabricate(:user)
    user.change_trust_level!(:basic)

    category = Fabricate(:category)
    category.deny(:all)
    category.allow(Group[:trust_level_1])
    category.save

    post = PostCreator.create(user, raw: "this is my new post 123 post", title: "hello world")

    CategoryFeaturedTopic.feature_topics_for(category)
    CategoryFeaturedTopic.count.should == 1

  end

end

