# encoding: utf-8

require 'spec_helper'
require_dependency 'post_creator'

describe Category do
  it { should validate_presence_of :user_id }
  it { should validate_presence_of :name }

  it 'validates uniqueness of name' do
    Fabricate(:category)
    should validate_uniqueness_of(:name).scoped_to(:parent_category_id)
  end

  it 'validates uniqueness in case insensitive way' do
    Fabricate(:category, name: "Cats")
    c = Fabricate.build(:category, name: "cats")
    c.should_not be_valid
    c.errors[:name].should be_present
  end

  describe "last_updated_at" do
    it "returns a number value of when the category was last updated" do
      last = Category.last_updated_at
      last.should be_present
      last.to_i.should == last
    end
  end

  describe "resolve_permissions" do
    it "can determine read_restricted" do
      read_restricted, resolved = Category.resolve_permissions(:everyone => :full)

      read_restricted.should == false
      resolved.should == []
    end
  end

  describe "topic_create_allowed and post_create_allowed" do
    it "works" do

      # NOTE we also have the uncategorized category ... hence the increased count

      _default_category = Fabricate(:category)
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
      category.read_restricted?.should == false

      category.set_permissions({})
      category.read_restricted?.should == true

      category.set_permissions(:everyone => :full)
      category.read_restricted?.should == false

      user.secure_categories.should be_empty

      group.add(user)
      group.save

      category.set_permissions(group.id => :full)
      category.save

      user.reload
      user.secure_categories.should == [category]
    end

    it "lists all secured categories correctly" do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)

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

  it "sets name_lower" do
    Fabricate(:category, name: "Not MySQL").name_lower.should == "not mysql"
  end

  it "has custom fields" do
    category = Fabricate(:category, name: " music")
    category.custom_fields["a"].should == nil

    category.custom_fields["bob"] = "marley"
    category.custom_fields["jack"] = "black"
    category.save

    category = Category.find(category.id)
    category.custom_fields.should == {"bob" => "marley", "jack" => "black"}
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

  describe 'non-english characters' do
    let(:category) { Fabricate(:category, name: "電車男") }

    it "creates a blank slug, this is OK." do
      category.slug.should be_blank
      category.slug_for_url.should == "#{category.id}-category"
    end
  end

  describe 'slug would be a number' do
    let(:category) { Fabricate(:category, name: "電車男 2") }

    it 'creates a blank slug' do
      category.slug.should be_blank
      category.slug_for_url.should == "#{category.id}-category"
    end
  end

  describe 'description_text' do
    it 'correctly generates text description as needed' do
      c = Category.new
      c.description_text.should == nil
      c.description = "&lt;hello <a>test</a>."
      c.description_text.should == "<hello test."
    end
  end

  describe 'after create' do
    before do
      @category = Fabricate(:category, name: 'Amazing Category')
      @topic = @category.topic
    end

    it 'is created correctly' do
      @category.slug.should == 'amazing-category'
      @category.slug_for_url.should == @category.slug

      @category.description.should be_blank

      Topic.where(category_id: @category).count.should == 1

      @topic.should be_present

      @topic.category.should == @category

      @topic.should be_visible

      @topic.pinned_at.should be_present

      Guardian.new(@category.user).can_delete?(@topic).should == false

      @topic.posts.count.should == 1

      @category.topic_url.should be_present

      @category.posts_week.should  == 0
      @category.posts_month.should == 0
      @category.posts_year.should  == 0

      @category.topics_week.should  == 0
      @category.topics_month.should == 0
      @category.topics_year.should  == 0
    end

    it "renames the definition when renamed" do
      @category.update_attributes(name: 'Troutfishing')
      @topic.reload
      @topic.title.should =~ /Troutfishing/
    end

    it "doesn't raise an error if there is no definition topic to rename (uncategorized)" do
      -> { @category.update_attributes(name: 'Troutfishing', topic_id: nil) }.should_not raise_error
    end

    it "should not set its description topic to auto-close" do
      category = Fabricate(:category, name: 'Closing Topics', auto_close_hours: 1)
      category.topic.auto_close_at.should == nil
    end

    describe "creating a new category with the same slug" do
      it "should have a blank slug if at the same level" do
        category = Fabricate(:category, name: "Amazing Categóry")
        category.slug.should be_blank
        category.slug_for_url.should == "#{category.id}-category"
      end

      it "doesn't have a blank slug if not at the same level" do
        parent = Fabricate(:category, name: 'Other parent')
        category = Fabricate(:category, name: "Amazing Categóry", parent_category_id: parent.id)
        category.slug.should == 'amazing-category'
        category.slug_for_url.should == "amazing-category"
      end
    end

    describe "trying to change the category topic's category" do
      before do
        @new_cat = Fabricate(:category, name: '2nd Category', user: @category.user)
        @topic.change_category_to_id(@new_cat.id)
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
      Category.exists?(id: @category_id).should == false
      Topic.exists?(id: @topic_id).should == false
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

      post3.reload

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
        @category.posts_year.should == 1
        @category.posts_month.should == 1
        @category.posts_week.should == 1
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
        @category.posts_year.should == 0
        @category.posts_month.should == 0
        @category.posts_week.should == 0
      end
    end

    context 'with revised post' do
      before do
        post = create_post(user: @category.user, category: @category.name)

        SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
        post.revise(post.user, { raw: 'updated body' }, revised_at: post.updated_at + 2.minutes)

        Category.update_stats
        @category.reload
      end

      it "doesn't count each version of a post" do
        @category.post_count.should == 1
        @category.posts_year.should == 1
        @category.posts_month.should == 1
        @category.posts_week.should == 1
      end
    end

    context 'for uncategorized category' do
      before do
        @uncategorized = Category.find(SiteSetting.uncategorized_category_id)
        create_post(user: Fabricate(:user), category: @uncategorized.name)
        Category.update_stats
        @uncategorized.reload
      end

      it 'updates topic stats' do
        @uncategorized.topics_week.should == 1
        @uncategorized.topics_month.should == 1
        @uncategorized.topics_year.should == 1
        @uncategorized.topic_count.should == 1
        @uncategorized.post_count.should == 1
        @uncategorized.posts_year.should == 1
        @uncategorized.posts_month.should == 1
        @uncategorized.posts_week.should == 1
      end
    end
  end

  describe "#url" do
    it "builds a url for normal categories" do
      category = Fabricate(:category, name: "cats")
      expect(category.url).to eq "/category/cats"
    end

    describe "for subcategories" do
      it "includes the parent category" do
        parent_category = Fabricate(:category, name: "parent")
        subcategory = Fabricate(:category, name: "child",
                                parent_category_id: parent_category.id)
        expect(subcategory.url).to eq "/category/parent/child"
      end
    end
  end

  describe "uncategorized" do
    let(:cat) { Category.where(id: SiteSetting.uncategorized_category_id).first }

    it "reports as `uncategorized?`" do
      cat.should be_uncategorized
    end

    it "cannot have a parent category" do
      cat.parent_category_id = Fabricate(:category).id
      cat.should_not be_valid
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

    describe ".query_parent_category" do
      it "should return the parent category id given a parent slug" do
        parent_category.name = "Amazing Category"
        parent_category.id.should == Category.query_parent_category(parent_category.slug)
      end
    end

    describe ".query_category" do
      it "should return the category" do
        category = Fabricate(:category, name: "Amazing Category", parent_category_id: parent_category.id, user: user)
        parent_category.name = "Amazing Parent Category"
        category.should == Category.query_category(category.slug, parent_category.id)
      end
    end

  end

  describe "find_by_email" do
    it "is case insensitive" do
      c1 = Fabricate(:category, email_in: 'lower@example.com')
      c2 = Fabricate(:category, email_in: 'UPPER@EXAMPLE.COM')
      c3 = Fabricate(:category, email_in: 'Mixed.Case@Example.COM')
      Category.find_by_email('LOWER@EXAMPLE.COM').should == c1
      Category.find_by_email('upper@example.com').should == c2
      Category.find_by_email('mixed.case@example.com').should == c3
      Category.find_by_email('MIXED.CASE@EXAMPLE.COM').should == c3
    end
  end

end
