# encoding: utf-8

require 'spec_helper'
require_dependency 'post_creator'

describe Category do
  it { should validate_presence_of :user_id }
  it { should validate_presence_of :name }

  it 'validates uniqueness of name' do
    Fabricate(:category)
    should validate_uniqueness_of(:name)
  end

  it { should belong_to :topic }
  it { should belong_to :user }

  it { should have_many :topics }
  it { should have_many :category_featured_topics }
  it { should have_many :featured_topics }
  it { should belong_to :parent_category}

  describe "resolve_permissions" do
    it "can determine read_restricted" do
      read_restricted, resolved = Category.resolve_permissions(:everyone => :full)

      read_restricted.should be_false
      resolved.should == []
    end
  end

  describe "topic_create_allowed and post_create_allowed" do
    it "works" do

      # NOTE we also have the uncategorized category ... hence the increased count

      default_category = Fabricate(:category)
      full_category = Fabricate(:category)
      can_post_category = Fabricate(:category)
      can_read_category = Fabricate(:category)


      user = Fabricate(:user)
      group = Fabricate(:group)
      group.add(user)
      group.save

      admin = Fabricate(:admin)

      full_category.set_permissions(group => :full)
      full_category.save

      can_post_category.set_permissions(group => :create_post)
      can_post_category.save

      can_read_category.set_permissions(group => :readonly)
      can_read_category.save

      guardian = Guardian.new(admin)
      Category.topic_create_allowed(guardian).count.should == 5
      Category.post_create_allowed(guardian).count.should == 5
      Category.secured(guardian).count.should == 5

      guardian = Guardian.new(user)
      Category.secured(guardian).count.should == 5
      Category.post_create_allowed(guardian).count.should == 4
      Category.topic_create_allowed(guardian).count.should == 3 # explicitly allowed once, default allowed once

      # everyone has special semantics, test it as well
      can_post_category.set_permissions(:everyone => :create_post)
      can_post_category.save

      Category.post_create_allowed(guardian).count.should == 4

      # anonymous has permission to create no topics
      guardian = Guardian.new(nil)
      Category.post_create_allowed(guardian).count.should == 0

    end

  end

  describe "security" do
    let(:category) { Fabricate(:category) }
    let(:category_2) { Fabricate(:category) }
    let(:user) { Fabricate(:user) }
    let(:group) { Fabricate(:group) }

    it "secures categories correctly" do
      category.read_restricted?.should be_false

      category.set_permissions({})
      category.read_restricted?.should be_true

      category.set_permissions(:everyone => :full)
      category.read_restricted?.should be_false

      user.secure_categories.should be_empty

      group.add(user)
      group.save

      category.set_permissions(group.id => :full)
      category.save

      user.reload
      user.secure_categories.should == [category]
    end

    it "lists all secured categories correctly" do
      uncategorized = Category.first

      group.add(user)
      category.set_permissions(group.id => :full)
      category.save
      category_2.set_permissions(group.id => :full)
      category_2.save

      Category.secured.should =~ [uncategorized]
      Category.secured(Guardian.new(user)).should =~ [uncategorized,category, category_2]
    end
  end

  it "strips leading blanks" do
    Fabricate(:category, name: " music").name.should == "music"
  end

  it "strips trailing blanks" do
    Fabricate(:category, name: "bugs ").name.should == "bugs"
  end

  it "strips leading and trailing blanks" do
    Fabricate(:category, name: "  blanks ").name.should == "blanks"
  end

  describe "short name" do
    let!(:category) { Fabricate(:category, name: 'xx') }

    it "creates the category" do
      category.should be_present
    end

    it 'has one topic' do
      Topic.where(category_id: category.id).count.should == 1
    end
  end

  describe 'caching' do
    it "invalidates the site cache on creation" do
      Site.expects(:invalidate_cache).once
      Fabricate(:category)
    end

    it "invalidates the site cache on update" do
      cat = Fabricate(:category)
      Site.expects(:invalidate_cache).once
      cat.update_attributes(name: 'new name')
    end

    it "invalidates the site cache on destroy" do
      cat = Fabricate(:category)
      Site.expects(:invalidate_cache).once
      cat.destroy
    end
  end

  describe 'non-english characters' do
    let(:category) { Fabricate(:category, name: "電車男") }

    it "creates a blank slug, this is OK." do
      category.slug.should be_blank
    end
  end

  describe 'slug would be a number' do
    let(:category) { Fabricate(:category, name: "電車男 2") }

    it 'creates a blank slug' do
      category.slug.should be_blank
    end
  end

  describe 'after create' do
    before do
      @category = Fabricate(:category, name: 'Amazing Category')
      @topic = @category.topic
    end

    it 'is created correctly' do
      @category.slug.should == 'amazing-category'

      @category.hotness.should == 5.0

      @category.description.should be_blank

      Topic.where(category_id: @category).count.should == 1

      @topic.should be_present

      @topic.category.should == @category

      @topic.should be_visible

      @topic.pinned_at.should be_present

      Guardian.new(@category.user).can_delete?(@topic).should be_false

      @topic.posts.count.should == 1

      @category.topic_url.should be_present
    end

    describe "creating a new category with the same slug" do
      it "should have a blank slug" do
        Fabricate(:category, name: "Amazing Categóry").slug.should be_blank
      end
    end

    describe "trying to change the category topic's category" do
      before do
        @new_cat = Fabricate(:category, name: '2nd Category', user: @category.user)
        @topic.change_category(@new_cat.name)
        @topic.reload
        @category.reload
      end

      it 'does not cause changes' do
        @category.topic_count.should == 0
        @topic.category.should == @category
        @category.topic.should == @topic
      end
    end
  end

  describe 'destroy' do
    before do
      @category = Fabricate(:category)
      @category_id = @category.id
      @topic_id = @category.topic_id
      @category.destroy
    end

    it 'is deleted correctly' do
      Category.exists?(id: @category_id).should be_false
      Topic.exists?(id: @topic_id).should be_false
    end
  end

  describe 'latest' do
    it 'should be updated correctly' do
      category = Fabricate(:category)
      post = create_post(category: category.name)

      category.reload
      category.latest_post_id.should == post.id
      category.latest_topic_id.should == post.topic_id

      post2 = create_post(category: category.name)
      post3 = create_post(topic_id: post.topic_id, category: category.name)

      category.reload
      category.latest_post_id.should == post3.id
      category.latest_topic_id.should == post2.topic_id


      destroyer = PostDestroyer.new(Fabricate(:admin), post3)
      destroyer.destroy

      category.reload
      category.latest_post_id.should == post2.id
    end
  end

  describe 'update_stats' do
    before do
      @category = Fabricate(:category)
    end

    context 'with regular topics' do
      before do
        create_post(user: @category.user, category: @category.name)
        Category.update_stats
        @category.reload
      end

      it 'updates topic stats' do
        @category.topics_week.should == 1
        @category.topics_month.should == 1
        @category.topics_year.should == 1
        @category.topic_count.should == 1
        @category.post_count.should == 1
      end

    end

    context 'with deleted topics' do
      before do
        @category.topics << Fabricate(:deleted_topic,
                                      user: @category.user)
        Category.update_stats
        @category.reload
      end

      it 'does not count deleted topics' do
        @category.topics_week.should == 0
        @category.topic_count.should == 0
        @category.topics_month.should == 0
        @category.topics_year.should == 0
        @category.post_count.should == 0
      end

    end
  end


  describe "parent categories" do
    let(:user) { Fabricate(:user) }
    let(:parent_category) { Fabricate(:category, user: user) }

    it "can be associated with a parent category" do
      sub_category = Fabricate.build(:category, parent_category_id: parent_category.id, user: user)
      sub_category.should be_valid
      sub_category.parent_category.should == parent_category
    end

    it "cannot associate a category with itself" do
      category = Fabricate(:category, user: user)
      category.parent_category_id = category.id
      category.should_not be_valid
    end

    it "cannot have a category two levels deep" do
      sub_category = Fabricate(:category, parent_category_id: parent_category.id, user: user)
      nested_sub_category = Fabricate.build(:category, parent_category_id: sub_category.id, user: user)
      nested_sub_category.should_not be_valid

    end

  end

end
