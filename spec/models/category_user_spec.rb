# encoding: utf-8

require 'spec_helper'
require_dependency 'post_creator'

describe CategoryUser do

  it 'allows batch set' do
    user = Fabricate(:user)
    category1 = Fabricate(:category)
    category2 = Fabricate(:category)

    watching = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:watching])

    CategoryUser.batch_set(user, :watching, [category1.id, category2.id])
    watching.pluck(:category_id).sort.should == [category1.id, category2.id]

    CategoryUser.batch_set(user, :watching, [])
    watching.count.should == 0

    CategoryUser.batch_set(user, :watching, [category2.id])
    watching.count.should == 1
  end


  context 'integration' do
    before do
      ActiveRecord::Base.observers.enable :all
    end

    it 'should operate correctly' do
      watched_category = Fabricate(:category)
      muted_category = Fabricate(:category)
      tracked_category = Fabricate(:category)

      user = Fabricate(:user)

      CategoryUser.create!(user: user, category: watched_category, notification_level: CategoryUser.notification_levels[:watching])
      CategoryUser.create!(user: user, category: muted_category, notification_level: CategoryUser.notification_levels[:muted])
      CategoryUser.create!(user: user, category: tracked_category, notification_level: CategoryUser.notification_levels[:tracking])

      watched_post = create_post(category: watched_category)
      muted_post = create_post(category: muted_category)
      tracked_post = create_post(category: tracked_category)

      Notification.where(user_id: user.id, topic_id: watched_post.topic_id).count.should == 1
      Notification.where(user_id: user.id, topic_id: tracked_post.topic_id).count.should == 0

      tu = TopicUser.get(tracked_post.topic, user)
      tu.notification_level.should == TopicUser.notification_levels[:tracking]
      tu.notifications_reason_id.should == TopicUser.notification_reasons[:auto_track_category]

    end

  end
end

# A Category Moderator is marked by the `moderator` flag in the CategoryUser table.
# The tests here span several different Guardian models.
describe "Category Moderator" do

  context "an unmoderated category" do
    before do
      @category = Fabricate(:category)
    end

    it "has no moderators" do
      @category.should_not be_moderated
      @category.moderators.should be_empty
    end

    it "accepts moderator appointments" do
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)
      @category.appoint_moderator(user1)
      @category.appoint_moderator(user2)

      @category.should be_moderated
      @category.moderators.to_set.should eq([user1, user2].to_set)

      [user1, user2].each do |u|
        u.should be_moderating
        u.doth_moderate?(@category).should be_truthy
        u.moderated_categories.should eq([@category])
      end
    end

    it "can appoint existing category users" do
      user3 = Fabricate(:user)

      CategoryUser.set_notification_level_for_category(user3, 2, @category.id)
      @category.category_users.count.should eq(1)
      @category.appoint_moderator(user3)
      @category.category_users.count.should eq(1)
    end
  end

  context "a moderated category" do
    before do
      @category = Fabricate(:category)
      @category.appoint_moderator(Fabricate(:user))
    end

    it "has a moderator" do
      @category.should be_moderated
    end
  end

  context "a category moderator" do
    before do
      @category = Fabricate(:category)
      @moderator = Fabricate(:user)
      @category.appoint_moderator(@moderator)
      @topic = Fabricate(:topic, category: @category)
      @guardian = Guardian.new(@moderator)
    end

    it "can be dismissed" do
      @category.dismiss_moderator(@moderator)
      @category.reload

      @category.should_not be_moderated
      # not deleted, just demoted
      @category.category_users.should_not be_empty
    end

    it "can edit (rename) the category" do
      @guardian.can_edit?(@category).should be_truthy
    end

    it "can see, create & moderate (post, close, open, unlist, pin, archive) any topic in the category" do
      @guardian.can_see_topic?(@topic).should be_truthy
      @guardian.can_create_topic_on_category?(@category).should be_truthy
      @guardian.can_moderate?(@topic).should be_truthy
    end

    it "can edit (rename) & recategorize any topic in the category" do
      @guardian.can_edit?(@topic).should be_truthy
    end

    it "cannot appoint or dismiss moderators" do
      @guardian.can_appoint_moderator?(@category).should be_falsey
      @guardian.can_dismiss_moderator?(@category).should be_falsey
    end

    it "can create sub-categories" do
      @guardian.can_create?(@category).should be_truthy
    end

    it "can moderate any sub-categories" do
      subcat = Fabricate(:category, name: "Subcategory")
      subcat.parent_category = @category
      subcat.save

      @guardian.can_moderate?(subcat).should be_truthy
    end

    it "can delete & edit posts" do
      post = Fabricate.build(:post, topic: @topic)
      @guardian.can_delete?(post).should be_truthy
      @guardian.can_edit?(post).should be_truthy
      @guardian.can_see_post?(post).should be_truthy
    end

    it "can invite users" do
      @guardian.can_invite_to_forum?.should be_truthy
    end

    it "can edit, delete, wikify posts" do
      post1 = Fabricate(:post, topic: @topic)
      post2 = Fabricate(:post, topic: @topic)
      @guardian.can_edit?(post1).should be_truthy
      @guardian.can_delete?(post2).should be_truthy # never delete first post
      @guardian.can_wiki?(post1).should be_truthy
    end

    # TODO: see CategoriesController#upload; should be validating permission
    # for the specific category, but category_id is not currently provided;
    # update this when the client side can be updated to match
    it "can upload images for category" do
      @guardian.can_upload_for_category?.should be_truthy
    end
  end

end
