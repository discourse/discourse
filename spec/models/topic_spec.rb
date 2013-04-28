# encoding: UTF-8

require 'spec_helper'
require_dependency 'post_destroyer'

describe Topic do

  it { should validate_presence_of :title }

  it { should belong_to :category }
  it { should belong_to :user }
  it { should belong_to :last_poster }
  it { should belong_to :featured_user1 }
  it { should belong_to :featured_user2 }
  it { should belong_to :featured_user3 }
  it { should belong_to :featured_user4 }

  it { should have_many :posts }
  it { should have_many :topic_users }
  it { should have_many :topic_links }
  it { should have_many :topic_allowed_users }
  it { should have_many :allowed_users }
  it { should have_many :invites }

  it { should rate_limit }

  it_behaves_like "a versioned model"

  context '.title_quality' do

    it "strips a title when identifying length" do
      Fabricate.build(:topic, title: (" " * SiteSetting.min_topic_title_length) + "x").should_not be_valid
    end

    it "doesn't allow a long title" do
      Fabricate.build(:topic, title: "x" * (SiteSetting.max_topic_title_length + 1)).should_not be_valid
    end

    it "doesn't allow a short title" do
      Fabricate.build(:topic, title: "x" * (SiteSetting.min_topic_title_length + 1)).should_not be_valid
    end

    it "allows a regular title with a few ascii characters" do
      Fabricate.build(:topic, title: "hello this is my cool topic! welcome: all;").should be_valid
    end

    it "allows non ascii" do
      Fabricate.build(:topic, title: "Iñtërnâtiônàlizætiøn").should be_valid
    end

  end

  context 'slug' do

    let(:title) { "hello world topic" }
    let(:slug) { "hello-world-slug" }

    it "returns a Slug for a title" do
      Slug.expects(:for).with(title).returns(slug)
      Fabricate.build(:topic, title: title).slug.should == slug
    end

    it "returns 'topic' when the slug is empty (say, non-english chars)" do
      Slug.expects(:for).with(title).returns("")
      Fabricate.build(:topic, title: title).slug.should == "topic"
    end

  end

  context 'topic title uniqueness' do

    let!(:topic) { Fabricate(:topic) }
    let(:new_topic) { Fabricate.build(:topic, title: topic.title) }

    context "when duplicates aren't allowed" do
      before do
        SiteSetting.expects(:allow_duplicate_topic_titles?).returns(false)
      end

      it "won't allow another topic to be created with the same name" do
        new_topic.should_not be_valid
      end

      it "won't allow another topic with an upper case title to be created" do
        new_topic.title = new_topic.title.upcase
        new_topic.should_not be_valid
      end

      it "allows it when the topic is deleted" do
        topic.destroy
        new_topic.should be_valid
      end

      it "allows a private message to be created with the same topic" do
        new_topic.archetype = Archetype.private_message
        new_topic.should be_valid
      end
    end

    context "when duplicates are allowed" do
      before do
        SiteSetting.expects(:allow_duplicate_topic_titles?).returns(true)
      end

      it "won't allow another topic to be created with the same name" do
        new_topic.should be_valid
      end
    end

  end

  context 'html in title' do

    def build_topic_with_title(title)
      t = build(:topic, title: title)
      t.sanitize_title
      t.title_quality
      t
    end

    let(:topic_bold) { build_topic_with_title("Topic with <b>bold</b> text in its title" ) }
    let(:topic_image) { build_topic_with_title("Topic with <img src='something'> image in its title" ) }
    let(:topic_script) { build_topic_with_title("Topic with <script>alert('title')</script> script in its title" ) }

    it "escapes script contents" do
      topic_script.title.should == "Topic with script in its title"
    end

    it "escapes bold contents" do
      topic_bold.title.should == "Topic with bold text in its title"
    end

    it "escapes image contents" do
      topic_image.title.should == "Topic with image in its title"
    end

  end

  context 'fancy title' do
    let(:topic) { Fabricate.build(:topic, title: "\"this topic\" -- has ``fancy stuff''" ) }

    context 'title_fancy_entities disabled' do
      before do
        SiteSetting.stubs(:title_fancy_entities).returns(false)
      end

      it "doesn't change the title to add entities" do
        topic.fancy_title.should == topic.title
      end
    end

    context 'title_fancy_entities enabled' do
      before do
        SiteSetting.stubs(:title_fancy_entities).returns(true)
      end

      it "converts the title to have fancy entities" do
        topic.fancy_title.should == "&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;"
      end
    end


  end


  context 'similar_to' do

    it 'returns blank with nil params' do
      Topic.similar_to(nil, nil).should be_blank
    end

    context 'with a similar topic' do
      let!(:topic) { Fabricate(:topic, title: "Evil trout is the dude who posted this topic") }

      it 'returns the similar topic if the title is similar' do
        Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?").should == [topic]
      end

    end

  end

  context 'message bus' do
    it 'calls the message bus observer after create' do
      MessageBusObserver.any_instance.expects(:after_create_topic).with(instance_of(Topic))
      Fabricate(:topic)
    end
  end

  context 'post_numbers' do
    let!(:topic) { Fabricate(:topic) }
    let!(:p1) { Fabricate(:post, topic: topic, user: topic.user) }
    let!(:p2) { Fabricate(:post, topic: topic, user: topic.user) }
    let!(:p3) { Fabricate(:post, topic: topic, user: topic.user) }

    it "returns the post numbers of the topic" do
      topic.post_numbers.should == [1, 2, 3]
      p2.destroy
      topic.reload
      topic.post_numbers.should == [1, 3]
    end

  end

  context 'move_posts' do
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:evil_trout) }
    let(:category) { Fabricate(:category, user: user) }
    let!(:topic) { Fabricate(:topic, user: user, category: category) }
    let!(:p1) { Fabricate(:post, topic: topic, user: user) }
    let!(:p2) { Fabricate(:post, topic: topic, user: another_user)}
    let!(:p3) { Fabricate(:post, topic: topic, user: user)}
    let!(:p4) { Fabricate(:post, topic: topic, user: user)}

    before do
      # add a like to a post
      PostAction.act(another_user, p4, PostActionType.types[:like])
    end

    context 'success' do

      it "enqueues a job to notify users" do
        topic.stubs(:add_moderator_post)
        Jobs.expects(:enqueue).with(:notify_moved_posts, post_ids: [p1.id, p4.id], moved_by_id: user.id)
        topic.move_posts(user, "new testing topic name", [p1.id, p4.id])
      end

      it "adds a moderator post at the location of the first moved post" do
        topic.expects(:add_moderator_post).with(user, instance_of(String), has_entries(post_number: 2))
        topic.move_posts(user, "new testing topic name", [p2.id, p4.id])
      end

    end

    context "errors" do

      it "raises an error when one of the posts doesn't exist" do
        lambda { topic.move_posts(user, "new testing topic name", [1003]) }.should raise_error(Discourse::InvalidParameters)
      end

      it "raises an error if no posts were moved" do
        lambda { topic.move_posts(user, "new testing topic name", []) }.should raise_error(Discourse::InvalidParameters)
      end

    end

    context "afterwards" do
      before do
        topic.expects(:add_moderator_post)
        TopicUser.update_last_read(user, topic.id, p4.post_number, 0)
      end

      let!(:new_topic) { topic.move_posts(user, "new testing topic name", [p2.id, p4.id]) }

      it "moved correctly" do
        TopicUser.where(user_id: user.id, topic_id: topic.id).first.last_read_post_number.should == p3.post_number

        new_topic.should be_present
        new_topic.featured_user1_id.should == another_user.id
        new_topic.like_count.should == 1
        new_topic.category.should == category
        topic.featured_user1_id.should be_blank
        new_topic.posts.should =~ [p2, p4]

        new_topic.reload
        new_topic.posts_count.should == 2
        new_topic.highest_post_number.should == 2

        p2.reload
        p2.sort_order.should == 1
        p2.post_number.should == 1

        p4.reload
        p4.post_number.should == 2
        p4.sort_order.should == 2

        topic.reload
        topic.featured_user1_id.should be_blank
        topic.like_count.should == 0
        topic.posts_count.should == 2
        topic.posts.should =~ [p1, p3]
        topic.highest_post_number.should == p3.post_number
      end
    end
  end

  context 'private message' do
    let(:coding_horror) { User.where(username: 'CodingHorror').first }
    let(:evil_trout) { Fabricate(:evil_trout) }
    let!(:topic) { Fabricate(:private_message_topic) }

    it "should integrate correctly" do
      Guardian.new(topic.user).can_see?(topic).should be_true
      Guardian.new.can_see?(topic).should be_false
      Guardian.new(evil_trout).can_see?(topic).should be_false
      Guardian.new(coding_horror).can_see?(topic).should be_true
      TopicQuery.new(evil_trout).list_latest.topics.should_not include(topic)

      # invites
      topic.invite(topic.user, 'duhhhhh').should be_false
    end

    context 'invite' do

      it "delegates to topic.invite_by_email when the user doesn't exist, but it's an email" do
        topic.expects(:invite_by_email).with(topic.user, 'jake@adventuretime.ooo')
        topic.invite(topic.user, 'jake@adventuretime.ooo')
      end

      context 'existing user' do
        let(:walter) { Fabricate(:walter_white) }

        context 'by username' do
          it 'returns true' do
            topic.invite(topic.user, walter.username).should be_true
          end

          it 'adds walter to the allowed users' do
            topic.invite(topic.user, walter.username)
            topic.allowed_users.include?(walter).should be_true
          end

          it 'creates a notification' do
            lambda { topic.invite(topic.user, walter.username) }.should change(Notification, :count)
          end
        end

        context 'by email' do
          it 'returns true' do
            topic.invite(topic.user, walter.email).should be_true
          end

          it 'adds walter to the allowed users' do
            topic.invite(topic.user, walter.email)
            topic.allowed_users.include?(walter).should be_true
          end

          it 'creates a notification' do
            lambda { topic.invite(topic.user, walter.email) }.should change(Notification, :count)
          end

        end
      end

    end

    context "user actions" do
      let(:actions) { topic.user.user_actions }

      it "should set up actions correctly" do
        actions.map{|a| a.action_type}.should_not include(UserAction::NEW_TOPIC)
        actions.map{|a| a.action_type}.should include(UserAction::NEW_PRIVATE_MESSAGE)
        coding_horror.user_actions.map{|a| a.action_type}.should include(UserAction::GOT_PRIVATE_MESSAGE)
      end

    end

    context "other user" do

      let(:creator) { PostCreator.new(topic.user, raw: Fabricate.build(:post).raw, topic_id: topic.id )}

      it "sends the other user an email when there's a new post" do
        UserNotifications.expects(:private_message).with(coding_horror, has_key(:post))
        creator.create
      end

      it "doesn't send the user an email when they have them disabled" do
        coding_horror.update_column(:email_private_messages, false)
        UserNotifications.expects(:private_message).with(coding_horror, has_key(:post)).never
        creator.create
      end

    end


  end


  context 'bumping topics' do

    before do
      @topic = Fabricate(:topic, bumped_at: 1.year.ago)
    end


    it 'updates the bumped_at field when a new post is made' do
      @topic.bumped_at.should be_present
      lambda {
        Fabricate(:post, topic: @topic, user: @topic.user)
        @topic.reload
      }.should change(@topic, :bumped_at)
    end

    context 'editing posts' do
      before do
        @earlier_post = Fabricate(:post, topic: @topic, user: @topic.user)
        @last_post = Fabricate(:post, topic: @topic, user: @topic.user)
        @topic.reload
      end

      it "doesn't bump the topic on an edit to the last post that doesn't result in a new version" do
        lambda {
          SiteSetting.expects(:ninja_edit_window).returns(5.minutes)
          @last_post.revise(@last_post.user, 'updated contents', revised_at: @last_post.created_at + 10.seconds)
          @topic.reload
        }.should_not change(@topic, :bumped_at)
      end

      it "bumps the topic when a new version is made of the last post" do
        lambda {
          @last_post.revise(Fabricate(:moderator), 'updated contents')
          @topic.reload
        }.should change(@topic, :bumped_at)
      end

      it "doesn't bump the topic when a post that isn't the last post receives a new version" do
        lambda {
          @earlier_post.revise(Fabricate(:moderator), 'updated contents')
          @topic.reload
        }.should_not change(@topic, :bumped_at)
      end
    end
  end

  context 'moderator posts' do
    before do
      @moderator = Fabricate(:moderator)
      @topic = Fabricate(:topic)
      @mod_post = @topic.add_moderator_post(@moderator, "Moderator did something. http://discourse.org", post_number: 999)
    end

    it 'creates a moderator post' do
      @mod_post.should be_present
      @mod_post.post_type.should == Post.types[:moderator_action]
      @mod_post.post_number.should == 999
      @mod_post.sort_order.should == 999
      @topic.topic_links.count.should == 1
      @topic.reload
      @topic.moderator_posts_count.should == 1
    end
  end


  context 'update_status' do
    before do
      @topic = Fabricate(:topic, bumped_at: 1.hour.ago)
      @topic.reload
      @original_bumped_at = @topic.bumped_at.to_f
      @user = @topic.user
      @user.admin = true
    end

    context 'visibility' do
      context 'disable' do
        before do
          @topic.update_status('visible', false, @user)
          @topic.reload
        end

        it 'should not be visible and have correct counts' do
          @topic.should_not be_visible
          @topic.moderator_posts_count.should == 1
          @topic.bumped_at.to_f.should == @original_bumped_at
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :visible, false
          @topic.update_status('visible', true, @user)
          @topic.reload
        end

        it 'should be visible with correct counts' do
          @topic.should be_visible
          @topic.moderator_posts_count.should == 1
          @topic.bumped_at.to_f.should == @original_bumped_at
        end
      end
    end

    context 'pinned' do
      context 'disable' do
        before do
          @topic.update_status('pinned', false, @user)
          @topic.reload
        end

        it "doesn't have a pinned_at but has correct dates" do
          @topic.pinned_at.should be_blank
          @topic.moderator_posts_count.should == 1
          @topic.bumped_at.to_f.should == @original_bumped_at
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :pinned_at, nil
          @topic.update_status('pinned', true, @user)
          @topic.reload
        end

        it 'should enable correctly' do
          @topic.pinned_at.should be_present
          @topic.bumped_at.to_f.should == @original_bumped_at
          @topic.moderator_posts_count.should == 1
        end

      end
    end

    context 'archived' do
      context 'disable' do
        before do
          @topic.update_status('archived', false, @user)
          @topic.reload
        end

        it 'should archive correctly' do
          @topic.should_not be_archived
          @topic.bumped_at.to_f.should == @original_bumped_at
          @topic.moderator_posts_count.should == 1
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :archived, false
          @topic.update_status('archived', true, @user)
          @topic.reload
        end

        it 'should be archived' do
          @topic.should be_archived
          @topic.moderator_posts_count.should == 1
          @topic.bumped_at.to_f.should == @original_bumped_at
        end

      end
    end

    context 'closed' do
      context 'disable' do
        before do
          @topic.update_status('closed', false, @user)
          @topic.reload
        end

        it 'should not be pinned' do
          @topic.should_not be_closed
          @topic.moderator_posts_count.should == 1
          @topic.bumped_at.to_f.should_not == @original_bumped_at
        end

      end

      context 'enable' do
        before do
          @topic.update_attribute :closed, false
          @topic.update_status('closed', true, @user)
          @topic.reload
        end

        it 'should be closed' do
          @topic.should be_closed
          @topic.bumped_at.to_f.should == @original_bumped_at
          @topic.moderator_posts_count.should == 1
        end
      end
    end


  end

  describe 'toggle_star' do

    shared_examples_for "adding a star to a topic" do
      it 'triggers a forum topic user change with true' do
        # otherwise no chance the mock will work
        freeze_time do
          TopicUser.expects(:change).with(@user, @topic.id, starred: true, starred_at: DateTime.now, unstarred_at: nil)
          @topic.toggle_star(@user, true)
        end
      end

      it 'increases the star_count of the forum topic' do
        lambda {
          @topic.toggle_star(@user, true)
          @topic.reload
        }.should change(@topic, :star_count).by(1)
      end

      it 'triggers the rate limiter' do
        Topic::FavoriteLimiter.any_instance.expects(:performed!)
        @topic.toggle_star(@user, true)
      end
    end

    before do
      @topic = Fabricate(:topic)
      @user = @topic.user
    end

    it_should_behave_like "adding a star to a topic"

    describe 'removing a star' do
      before do
        @topic.toggle_star(@user, true)
        @topic.reload
      end

      it 'rolls back the rate limiter' do
        Topic::FavoriteLimiter.any_instance.expects(:rollback!)
        @topic.toggle_star(@user, false)
      end

      it 'triggers a forum topic user change with false' do
        freeze_time do
          TopicUser.expects(:change).with(@user, @topic.id, starred: false, unstarred_at: DateTime.now)
          @topic.toggle_star(@user, false)
        end
      end

      it 'reduces the star_count' do
        lambda {
          @topic.toggle_star(@user, false)
          @topic.reload
        }.should change(@topic, :star_count).by(-1)
      end

      describe 'and adding a star again' do
        before do
          @topic.toggle_star(@user, false)
          @topic.reload
        end
        it_should_behave_like "adding a star to a topic"
      end
    end
  end

  context 'last_poster info' do

    before do
      @user = Fabricate(:user)
      @post = Fabricate(:post, user: @user)
      @topic = @post.topic
    end

    it 'initially has the last_post_user_id of the OP' do
      @topic.last_post_user_id.should == @user.id
    end

    context 'after a second post' do
      before do
        @second_user = Fabricate(:coding_horror)
        @new_post = Fabricate(:post, topic: @topic, user: @second_user)
        @topic.reload
      end

      it 'updates the last_post_user_id to the second_user' do
        @topic.last_post_user_id.should == @second_user.id
        @topic.last_posted_at.to_i.should == @new_post.created_at.to_i
        topic_user = @second_user.topic_users.where(topic_id: @topic.id).first
        topic_user.posted?.should be_true
      end

    end
  end

  describe 'with category' do
    before do
      @category = Fabricate(:category)
    end

    it "should not increase the topic_count with no category" do
      lambda { Fabricate(:topic, user: @category.user); @category.reload }.should_not change(@category, :topic_count)
    end

    it "should increase the category's topic_count" do
      lambda { Fabricate(:topic, user: @category.user, category_id: @category.id); @category.reload }.should change(@category, :topic_count).by(1)
    end
  end

  describe 'meta data' do
    let(:topic) { Fabricate(:topic, meta_data: {hello: 'world'}) }

    it 'allows us to create a topic with meta data' do
      topic.meta_data['hello'].should == 'world'
    end

    context 'updating' do

      context 'existing key' do
        before do
          topic.update_meta_data(hello: 'bane')
        end

        it 'updates the key' do
          topic.meta_data['hello'].should == 'bane'
        end
      end

      context 'new key' do
        before do
          topic.update_meta_data(city: 'gotham')
        end

        it 'adds the new key' do
          topic.meta_data['city'].should == 'gotham'
          topic.meta_data['hello'].should == 'world'
        end

      end


    end

  end

  describe 'after create' do

    let(:topic) { Fabricate(:topic) }

    it 'is a regular topic by default' do
      topic.archetype.should == Archetype.default
      topic.has_best_of.should be_false
      topic.percent_rank.should == 1.0
      topic.should be_visible
      topic.pinned_at.should be_blank
      topic.should_not be_closed
      topic.should_not be_archived
      topic.moderator_posts_count.should == 0
    end

    context 'post' do
      let(:post) { Fabricate(:post, topic: topic, user: topic.user) }

      it 'has the same archetype as the topic' do
        post.archetype.should == topic.archetype
      end
    end
  end

  describe 'versions' do
    let(:topic) { Fabricate(:topic) }

    it "has version 1 by default" do
      topic.version.should == 1
    end

    context 'changing title' do
      before do
        topic.title = "new title for the topic"
        topic.save
      end

      it "creates a new version" do
        topic.version.should == 2
      end
    end

    context 'changing category' do
      let(:category) { Fabricate(:category) }

      before do
        topic.change_category(category.name)
      end

      it "creates a new version" do
        topic.version.should == 2
      end

      context "removing a category" do
        before do
          topic.change_category(nil)
        end

        it "creates a new version" do
          topic.version.should == 3
        end
      end

    end

    context 'bumping the topic' do
      before do
        topic.bumped_at = 10.minutes.from_now
        topic.save
      end

      it "doesn't craete a new version" do
        topic.version.should == 1
      end
    end

  end

  describe 'change_category' do

    before do
      @topic = Fabricate(:topic)
      @category = Fabricate(:category, user: @topic.user)
      @user = @topic.user
    end

    describe 'without a previous category' do

      it 'should not change the topic_count when not changed' do
       lambda { @topic.change_category(nil); @category.reload }.should_not change(@category, :topic_count)
      end

      describe 'changed category' do
        before do
          @topic.change_category(@category.name)
          @category.reload
        end

        it 'changes the category' do
          @topic.category.should == @category
          @category.topic_count.should == 1
        end

      end


      it "doesn't change the category when it can't be found" do
        @topic.change_category('made up')
        @topic.category.should be_blank
      end
    end

    describe 'with a previous category' do
      before do
        @topic.change_category(@category.name)
        @topic.reload
        @category.reload
      end

      it 'increases the topic_count' do
        @category.topic_count.should == 1
      end

      it "doesn't change the topic_count when the value doesn't change" do
        lambda { @topic.change_category(@category.name); @category.reload }.should_not change(@category, :topic_count)
      end

      it "doesn't reset the category when given a name that doesn't exist" do
        @topic.change_category('made up')
        @topic.category_id.should be_present
      end

      describe 'to a different category' do
        before do
          @new_category = Fabricate(:category, user: @user, name: '2nd category')
          @topic.change_category(@new_category.name)
          @topic.reload
          @new_category.reload
          @category.reload
        end

        it "should increase the new category's topic count" do
          @new_category.topic_count.should == 1
        end

        it "should lower the original category's topic count" do
          @category.topic_count.should == 0
        end

      end

      describe 'when the category exists' do
        before do
          @topic.change_category(nil)
          @category.reload
        end

        it "resets the category" do
          @topic.category_id.should be_blank
          @category.topic_count.should == 0
        end

      end

    end

  end

  describe 'scopes' do
    describe '#by_most_recently_created' do
      it 'returns topics ordered by created_at desc, id desc' do
        now = Time.now
        a = Fabricate(:topic, created_at: now - 2.minutes)
        b = Fabricate(:topic, created_at: now)
        c = Fabricate(:topic, created_at: now)
        d = Fabricate(:topic, created_at: now - 2.minutes)
        Topic.by_newest.should == [c,b,d,a]
      end
    end
  end

end
