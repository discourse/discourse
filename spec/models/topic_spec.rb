# encoding: UTF-8

require 'spec_helper'
require_dependency 'post_destroyer'

describe Topic do

  let(:now) { Time.zone.local(2013,11,20,8,0) }

  it { should validate_presence_of :title }

  it { should rate_limit }

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

  context "updating a title to be shorter" do
    let!(:topic) { Fabricate(:topic) }

    it "doesn't update it to be shorter due to cleaning using TextCleaner" do
      topic.title = 'unread    glitch'
      topic.save.should == false
    end
  end

  context 'private message title' do
    before do
      SiteSetting.stubs(:min_topic_title_length).returns(15)
      SiteSetting.stubs(:min_private_message_title_length).returns(3)
    end

    it 'allows shorter titles' do
      pm = Fabricate.build(:private_message_topic, title: 'a' * SiteSetting.min_private_message_title_length)
      expect(pm).to be_valid
    end

    it 'but not too short' do
      pm = Fabricate.build(:private_message_topic, title: 'a')
      expect(pm).to_not be_valid
    end
  end

  context 'admin topic title' do
    let(:admin) { Fabricate(:admin) }

    it 'allows really short titles' do
      pm = Fabricate.build(:private_message_topic, user: admin, title: 'a')
      expect(pm).to be_valid
    end

    it 'but not blank' do
      pm = Fabricate.build(:private_message_topic, title: '')
      expect(pm).to_not be_valid
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

      it "will allow another topic to be created with the same name" do
        new_topic.should be_valid
      end
    end

  end

  context 'html in title' do

    def build_topic_with_title(title)
      build(:topic, title: title).tap{ |t| t.valid? }
    end

    let(:topic_bold) { build_topic_with_title("Topic with <b>bold</b> text in its title" ) }
    let(:topic_image) { build_topic_with_title("Topic with <img src='something'> image in its title" ) }
    let(:topic_script) { build_topic_with_title("Topic with <script>alert('title')</script> script in its title" ) }

    it "escapes script contents" do
      topic_script.fancy_title.should == "Topic with &lt;script&gt;alert(&lsquo;title&rsquo;)&lt;/script&gt; script in its title"
    end

    it "escapes bold contents" do
      topic_bold.fancy_title.should == "Topic with &lt;b&gt;bold&lt;/b&gt; text in its title"
    end

    it "escapes image contents" do
      topic_image.fancy_title.should == "Topic with &lt;img src=&lsquo;something&rsquo;&gt; image in its title"
    end

  end

  context 'fancy title' do
    let(:topic) { Fabricate.build(:topic, title: "\"this topic\" -- has ``fancy stuff''" ) }

    context 'title_fancy_entities disabled' do
      before do
        SiteSetting.stubs(:title_fancy_entities).returns(false)
      end

      it "doesn't add entities to the title" do
        topic.fancy_title.should == "&quot;this topic&quot; -- has ``fancy stuff&#39;&#39;"
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

  context 'category validation' do
    context 'allow_uncategorized_topics is false' do
      before do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
      end

      it "does not allow nil category" do
        topic = Fabricate.build(:topic, category: nil)
        topic.should_not be_valid
        topic.errors[:category_id].should be_present
      end

      it "allows PMs" do
        topic = Fabricate.build(:topic, category: nil, archetype: Archetype.private_message)
        topic.should be_valid
      end

      it 'passes for topics with a category' do
        Fabricate.build(:topic, category: Fabricate(:category)).should be_valid
      end
    end

    context 'allow_uncategorized_topics is true' do
      before do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
      end

      it "passes for topics with nil category" do
        Fabricate.build(:topic, category: nil).should be_valid
      end

      it 'passes for topics with a category' do
        Fabricate.build(:topic, category: Fabricate(:category)).should be_valid
      end
    end
  end


  context 'similar_to' do

    it 'returns blank with nil params' do
      Topic.similar_to(nil, nil).should be_blank
    end

    context "with a category definition" do
      let!(:category) { Fabricate(:category) }

      it "excludes the category definition topic from similar_to" do
        Topic.similar_to('category definition for', "no body").should be_blank
      end
    end

    context 'with a similar topic' do
      let!(:topic) {
        ActiveRecord::Base.observers.enable :search_observer
        post = create_post(title: "Evil trout is the dude who posted this topic")
        post.topic
      }

      it 'returns the similar topic if the title is similar' do
        Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?").should == [topic]
      end

      context "secure categories" do

        let(:user) { Fabricate(:user) }
        let(:category) { Fabricate(:category, read_restricted: true) }

        before do
          topic.category = category
          topic.save
        end

        it "doesn't return topics from private categories" do
          expect(Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?", user)).to be_blank
        end

        it "should return the cat since the user can see it" do
          Guardian.any_instance.expects(:secure_category_ids).returns([category.id])
          expect(Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?", user)).to include(topic)
        end
      end

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


  context 'private message' do
    let(:coding_horror) { User.find_by(username: "CodingHorror") }
    let(:evil_trout) { Fabricate(:evil_trout) }
    let(:topic) { Fabricate(:private_message_topic) }

    it "should integrate correctly" do
      Guardian.new(topic.user).can_see?(topic).should == true
      Guardian.new.can_see?(topic).should == false
      Guardian.new(evil_trout).can_see?(topic).should == false
      Guardian.new(coding_horror).can_see?(topic).should == true
      TopicQuery.new(evil_trout).list_latest.topics.should_not include(topic)

      # invites
      topic.invite(topic.user, 'duhhhhh').should == false
    end

    context 'invite' do

      context 'existing user' do
        let(:walter) { Fabricate(:walter_white) }

        context 'by username' do

          it 'adds and removes walter to the allowed users' do
            topic.invite(topic.user, walter.username).should == true
            topic.allowed_users.include?(walter).should == true

            topic.remove_allowed_user(walter.username).should == true
            topic.reload
            topic.allowed_users.include?(walter).should == false
          end

          it 'creates a notification' do
            lambda { topic.invite(topic.user, walter.username) }.should change(Notification, :count)
          end
        end

        context 'by email' do

          it 'adds user correctly' do
            lambda {
              topic.invite(topic.user, walter.email).should == true
            }.should change(Notification, :count)
            topic.allowed_users.include?(walter).should == true
          end

        end
      end

    end

    context "user actions" do
      let(:actions) { topic.user.user_actions }

      it "should set up actions correctly" do
        ActiveRecord::Base.observers.enable :all

        actions.map{|a| a.action_type}.should_not include(UserAction::NEW_TOPIC)
        actions.map{|a| a.action_type}.should include(UserAction::NEW_PRIVATE_MESSAGE)
        coding_horror.user_actions.map{|a| a.action_type}.should include(UserAction::GOT_PRIVATE_MESSAGE)
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
        create_post(topic: @topic, user: @topic.user)
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
          @last_post.revise(@last_post.user, { raw: 'updated contents' }, revised_at: @last_post.created_at + 10.seconds)
          @topic.reload
        }.should_not change(@topic, :bumped_at)
      end

      it "bumps the topic when a new version is made of the last post" do
        lambda {
          @last_post.revise(Fabricate(:moderator), { raw: 'updated contents' })
          @topic.reload
        }.should change(@topic, :bumped_at)
      end

      it "doesn't bump the topic when a post that isn't the last post receives a new version" do
        lambda {
          @earlier_post.revise(Fabricate(:moderator), { raw: 'updated contents' })
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

    shared_examples_for 'a status that closes a topic' do
      context 'disable' do
        before do
          @topic.update_status(status, false, @user)
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
          @topic.update_status(status, true, @user)
          @topic.reload
        end

        it 'should be closed' do
          @topic.should be_closed
          @topic.bumped_at.to_f.should == @original_bumped_at
          @topic.moderator_posts_count.should == 1
        end
      end
    end

    context 'closed' do
      let(:status) { 'closed' }
      it_should_behave_like 'a status that closes a topic'
    end

    context 'autoclosed' do
      let(:status) { 'autoclosed' }
      it_should_behave_like 'a status that closes a topic'

      context 'topic was set to close when it was created' do
        it 'puts the autoclose duration in the moderator post' do
          freeze_time(Time.new(2000,1,1)) do
            @topic.created_at = 3.days.ago
            @topic.update_status(status, true, @user)
            expect(@topic.posts.last.raw).to include "closed after 3 days"
          end
        end
      end

      context 'topic was set to close after it was created' do
        it 'puts the autoclose duration in the moderator post' do
          freeze_time(Time.new(2000,1,1)) do
            @topic.created_at = 7.days.ago
            freeze_time(2.days.ago) do
              @topic.set_auto_close(48)
            end
            @topic.update_status(status, true, @user)
            expect(@topic.posts.last.raw).to include "closed after 2 days"
          end
        end
      end
    end
  end

  describe 'toggle_star' do

    shared_examples_for "adding a star to a topic" do
      it 'triggers a forum topic user change with true' do
        # otherwise no chance the mock will work
        freeze_time
        TopicUser.expects(:change).with(@user, @topic.id, starred: true, starred_at: DateTime.now, unstarred_at: nil)
        @topic.toggle_star(@user, true)
      end

      it 'increases the star_count of the forum topic' do
        lambda {
          @topic.toggle_star(@user, true)
          @topic.reload
        }.should change(@topic, :star_count).by(1)
      end

      it 'triggers the rate limiter' do
        Topic::StarLimiter.any_instance.expects(:performed!)
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
        Topic::StarLimiter.any_instance.expects(:rollback!)
        @topic.toggle_star(@user, false)
      end

      it 'triggers a forum topic user change with false' do
        freeze_time
        TopicUser.expects(:change).with(@user, @topic.id, starred: false, unstarred_at: DateTime.now)
        @topic.toggle_star(@user, false)
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

  describe "banner" do

    let(:topic) { Fabricate(:topic) }
    let(:user) { topic.user }
    let(:banner) { { html: "<p>BANNER</p>", url: topic.url, key: topic.id } }

    before { topic.stubs(:banner).returns(banner) }

    describe "make_banner!" do

      it "changes the topic archetype to 'banner'" do
        topic.expects(:add_moderator_post)
        MessageBus.expects(:publish).with("/site/banner", banner)
        topic.make_banner!(user)
        topic.archetype.should == Archetype.banner
      end

      it "ensures only one banner topic at all time" do
        banner_topic = Fabricate(:banner_topic)
        Topic.where(archetype: Archetype.banner).count.should == 1

        topic.make_banner!(user)
        Topic.where(archetype: Archetype.banner).count.should == 1
      end

    end

    describe "remove_banner!" do

      it "resets the topic archetype" do
        topic.expects(:add_moderator_post)
        MessageBus.expects(:publish).with("/site/banner", nil)
        topic.remove_banner!(user)
        topic.archetype.should == Archetype.default
      end

    end


  end

  context 'last_poster info' do

    before do
      @post = create_post
      @user = @post.user
      @topic = @post.topic
    end

    it 'initially has the last_post_user_id of the OP' do
      @topic.last_post_user_id.should == @user.id
    end

    context 'after a second post' do
      before do
        @second_user = Fabricate(:coding_horror)
        @new_post = create_post(topic: @topic, user: @second_user)
        @topic.reload
      end

      it 'updates the last_post_user_id to the second_user' do
        @topic.last_post_user_id.should == @second_user.id
        @topic.last_posted_at.to_i.should == @new_post.created_at.to_i
        topic_user = @second_user.topic_users.find_by(topic_id: @topic.id)
        topic_user.posted?.should == true
      end

    end
  end

  describe 'with category' do

    before do
      @category = Fabricate(:category)
    end

    it "should not increase the topic_count with no category" do
      -> { Fabricate(:topic, user: @category.user); @category.reload }.should_not change(@category, :topic_count)
    end

    it "should increase the category's topic_count" do
      -> { Fabricate(:topic, user: @category.user, category_id: @category.id); @category.reload }.should change(@category, :topic_count).by(1)
    end
  end

  describe 'meta data' do
    let(:topic) { Fabricate(:topic, meta_data: {'hello' => 'world'}) }

    it 'allows us to create a topic with meta data' do
      topic.meta_data['hello'].should == 'world'
    end

    context 'updating' do

      context 'existing key' do
        before do
          topic.update_meta_data('hello' => 'bane')
        end

        it 'updates the key' do
          topic.meta_data['hello'].should == 'bane'
        end
      end

      context 'new key' do
        before do
          topic.update_meta_data('city' => 'gotham')
        end

        it 'adds the new key' do
          topic.meta_data['city'].should == 'gotham'
          topic.meta_data['hello'].should == 'world'
        end

      end

      context 'new key' do
        before do
          topic.update_meta_data('other' => 'key')
          topic.save!
        end

        it "can be loaded" do
          Topic.find(topic.id).meta_data["other"].should == "key"
        end

        it "is in sync with custom_fields" do
          Topic.find(topic.id).custom_fields["other"].should == "key"
        end
      end


    end

  end

  describe 'after create' do

    let(:topic) { Fabricate(:topic) }

    it 'is a regular topic by default' do
      topic.archetype.should == Archetype.default
      topic.has_summary.should == false
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

  describe 'change_category' do

    before do
      @topic = Fabricate(:topic)
      @category = Fabricate(:category, user: @topic.user)
      @user = @topic.user
    end

    describe 'without a previous category' do

      it 'should not change the topic_count when not changed' do
       lambda { @topic.change_category_to_id(@topic.category.id); @category.reload }.should_not change(@category, :topic_count)
      end

      describe 'changed category' do
        before do
          @topic.change_category_to_id(@category.id)
          @category.reload
        end

        it 'changes the category' do
          @topic.category.should == @category
          @category.topic_count.should == 1
        end

      end

      it "doesn't change the category when it can't be found" do
        @topic.change_category_to_id(12312312)
        @topic.category_id.should == SiteSetting.uncategorized_category_id
      end
    end

    describe 'with a previous category' do
      before do
        @topic.change_category_to_id(@category.id)
        @topic.reload
        @category.reload
      end

      it 'increases the topic_count' do
        @category.topic_count.should == 1
      end

      it "doesn't change the topic_count when the value doesn't change" do
        lambda { @topic.change_category_to_id(@category.id); @category.reload }.should_not change(@category, :topic_count)
      end

      it "doesn't reset the category when given a name that doesn't exist" do
        @topic.change_category_to_id(55556)
        @topic.category_id.should be_present
      end

      describe 'to a different category' do
        before do
          @new_category = Fabricate(:category, user: @user, name: '2nd category')
          @topic.change_category_to_id(@new_category.id)
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

      context 'when allow_uncategorized_topics is false' do
        before do
          SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
        end

        let!(:topic) { Fabricate(:topic, category: Fabricate(:category)) }

        it 'returns false' do
          topic.change_category_to_id(nil).should eq(false) # don't use "== false" here because it would also match nil
        end
      end

      describe 'when the category exists' do
        before do
          @topic.change_category_to_id(nil)
          @category.reload
        end

        it "resets the category" do
          @topic.category_id.should == SiteSetting.uncategorized_category_id
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

    describe '#created_since' do
      it 'returns topics created after some date' do
        now = Time.now
        a = Fabricate(:topic, created_at: now - 2.minutes)
        b = Fabricate(:topic, created_at: now - 1.minute)
        c = Fabricate(:topic, created_at: now)
        d = Fabricate(:topic, created_at: now + 1.minute)
        e = Fabricate(:topic, created_at: now + 2.minutes)
        Topic.created_since(now).should_not include a
        Topic.created_since(now).should_not include b
        Topic.created_since(now).should_not include c
        Topic.created_since(now).should include d
        Topic.created_since(now).should include e
      end
    end

    describe '#visible' do
      it 'returns topics set as visible' do
        a = Fabricate(:topic, visible: false)
        b = Fabricate(:topic, visible: true)
        c = Fabricate(:topic, visible: true)
        Topic.visible.should_not include a
        Topic.visible.should include b
        Topic.visible.should include c
      end
    end
  end

  describe 'auto-close' do
    context 'a new topic' do
      context 'auto_close_at is set' do
        it 'queues a job to close the topic' do
          Timecop.freeze(now) do
            Jobs.expects(:enqueue_at).with(7.hours.from_now, :close_topic, all_of( has_key(:topic_id), has_key(:user_id) ))
            topic = Fabricate(:topic, user: Fabricate(:admin))
            topic.set_auto_close(7).save
          end
        end

        it 'when auto_close_user_id is nil, it will use the topic creator as the topic closer' do
          topic_creator = Fabricate(:admin)
          Jobs.expects(:enqueue_at).with do |datetime, job_name, job_args|
            job_args[:user_id] == topic_creator.id
          end
          topic = Fabricate(:topic, user: topic_creator)
          topic.set_auto_close(7).save
        end

        it 'when auto_close_user_id is set, it will use it as the topic closer' do
          topic_creator = Fabricate(:admin)
          topic_closer = Fabricate(:user, admin: true)
          Jobs.expects(:enqueue_at).with do |datetime, job_name, job_args|
            job_args[:user_id] == topic_closer.id
          end
          topic = Fabricate(:topic, user: topic_creator)
          topic.set_auto_close(7, topic_closer).save
        end

        it "ignores the category's default auto-close" do
          Timecop.freeze(now) do
            Jobs.expects(:enqueue_at).with(7.hours.from_now, :close_topic, all_of( has_key(:topic_id), has_key(:user_id) ))
            topic = Fabricate(:topic, user: Fabricate(:admin), ignore_category_auto_close: true, category_id: Fabricate(:category, auto_close_hours: 2).id)
            topic.set_auto_close(7).save
          end
        end

        it 'sets the time when auto_close timer starts' do
          Timecop.freeze(now) do
            topic = Fabricate(:topic,  user: Fabricate(:admin))
            topic.set_auto_close(7).save
            expect(topic.auto_close_started_at).to eq(now)
          end
        end
      end
    end

    context 'an existing topic' do
      it 'when auto_close_at is set, it queues a job to close the topic' do
        Timecop.freeze(now) do
          topic = Fabricate(:topic)
          Jobs.expects(:enqueue_at).with(12.hours.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: topic.user_id))
          topic.auto_close_at = 12.hours.from_now
          topic.save.should == true
        end
      end

      it 'when auto_close_at and auto_closer_user_id are set, it queues a job to close the topic' do
        Timecop.freeze(now) do
          topic  = Fabricate(:topic)
          closer = Fabricate(:admin)
          Jobs.expects(:enqueue_at).with(12.hours.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: closer.id))
          topic.auto_close_at = 12.hours.from_now
          topic.auto_close_user = closer
          topic.save.should == true
        end
      end

      it 'when auto_close_at is removed, it cancels the job to close the topic' do
        Jobs.stubs(:enqueue_at).returns(true)
        topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
        Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
        topic.auto_close_at = nil
        topic.save.should == true
        topic.auto_close_user.should == nil
      end

      it 'when auto_close_user is removed, it updates the job' do
        Timecop.freeze(now) do
          Jobs.stubs(:enqueue_at).with(1.day.from_now, :close_topic, anything).returns(true)
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now, auto_close_user: Fabricate(:admin))
          Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
          Jobs.expects(:enqueue_at).with(1.day.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: topic.user_id))
          topic.auto_close_user = nil
          topic.save.should == true
        end
      end

      it 'when auto_close_at value is changed, it reschedules the job' do
        Timecop.freeze(now) do
          Jobs.stubs(:enqueue_at).returns(true)
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
          Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
          Jobs.expects(:enqueue_at).with(3.days.from_now, :close_topic, has_entry(topic_id: topic.id))
          topic.auto_close_at = 3.days.from_now
          topic.save.should == true
        end
      end

      it 'when auto_close_user_id is changed, it updates the job' do
        Timecop.freeze(now) do
          admin = Fabricate(:admin)
          Jobs.stubs(:enqueue_at).returns(true)
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
          Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
          Jobs.expects(:enqueue_at).with(1.day.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: admin.id))
          topic.auto_close_user = admin
          topic.save.should == true
        end
      end

      it 'when auto_close_at and auto_close_user_id are not changed, it should not schedule another CloseTopic job' do
        Timecop.freeze(now) do
          Jobs.expects(:enqueue_at).with(1.day.from_now, :close_topic, has_key(:topic_id)).once.returns(true)
          Jobs.expects(:cancel_scheduled_job).never
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
          topic.title = 'A new title that is long enough'
          topic.save.should == true
        end
      end

      it "ignores the category's default auto-close" do
        Timecop.freeze(now) do
          mod = Fabricate(:moderator)
          # NOTE, only moderators can auto-close, if missing system user is used
          topic = Fabricate(:topic, category: Fabricate(:category, auto_close_hours: 14), user: mod)
          Jobs.expects(:enqueue_at).with(12.hours.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: topic.user_id))
          topic.auto_close_at = 12.hours.from_now
          topic.save

          topic.reload
          topic.closed.should == false

          Timecop.freeze(24.hours.from_now) do
            Topic.auto_close
            topic.reload
            topic.closed.should == true
          end

        end
      end
    end
  end

  describe 'set_auto_close' do
    let(:topic)         { Fabricate.build(:topic) }
    let(:closing_topic) { Fabricate.build(:topic, auto_close_hours: 5, auto_close_at: 5.hours.from_now, auto_close_started_at: 5.hours.from_now) }
    let(:admin)         { Fabricate.build(:user, id: 123) }

    before { Discourse.stubs(:system_user).returns(admin) }

    it 'can take a number of hours as an integer' do
      Timecop.freeze(now) do
        topic.set_auto_close(72, admin)
        expect(topic.auto_close_at).to eq(3.days.from_now)
      end
    end

    it 'can take a number of hours as a string' do
      Timecop.freeze(now) do
        topic.set_auto_close('18', admin)
        expect(topic.auto_close_at).to eq(18.hours.from_now)
      end
    end

    it "can take a time later in the day" do
      Timecop.freeze(now) do
        topic.set_auto_close('13:00', admin)
        topic.auto_close_at.should == Time.zone.local(2013,11,20,13,0)
      end
    end

    it "can take a time for the next day" do
      Timecop.freeze(now) do
        topic.set_auto_close('5:00', admin)
        topic.auto_close_at.should == Time.zone.local(2013,11,21,5,0)
      end
    end

    it "can take a timestamp for a future time" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-22 5:00', admin)
        topic.auto_close_at.should == Time.zone.local(2013,11,22,5,0)
      end
    end

    it "sets a validation error when given a timestamp in the past" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-19 5:00', admin)
        topic.auto_close_at.should == Time.zone.local(2013,11,19,5,0)
        topic.errors[:auto_close_at].should be_present
      end
    end

    it "can take a timestamp with timezone" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-25T01:35:00-08:00', admin)
        topic.auto_close_at.should == Time.utc(2013,11,25,9,35)
      end
    end

    it 'sets auto_close_user to given user if it is a staff user' do
      topic.set_auto_close(3, admin)
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to system user if given user is not staff' do
      topic.set_auto_close(3, Fabricate.build(:user, id: 444))
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to system_user if user is not given and topic creator is not staff' do
      topic.set_auto_close(3)
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to topic creator if it is a staff user' do
      staff_topic = Fabricate.build(:topic, user: Fabricate.build(:admin, id: 999))
      staff_topic.set_auto_close(3)
      expect(staff_topic.auto_close_user_id).to eq(999)
    end

    it 'clears auto_close_at if arg is nil' do
      closing_topic.set_auto_close(nil)
      expect(closing_topic.auto_close_at).to be_nil
    end

    it 'clears auto_close_started_at if arg is nil' do
      closing_topic.set_auto_close(nil)
      expect(closing_topic.auto_close_started_at).to be_nil
    end

    it 'updates auto_close_at if it was already set to close' do
      Timecop.freeze(now) do
        closing_topic.set_auto_close(48)
        expect(closing_topic.auto_close_at).to eq(2.days.from_now)
      end
    end

    it 'does not update auto_close_started_at if it was already set to close' do
      expect{
        closing_topic.set_auto_close(14)
      }.to_not change(closing_topic, :auto_close_started_at)
    end
  end

  describe 'for_digest' do
    let(:user) { Fabricate.build(:user) }

    it "returns none when there are no topics" do
      Topic.for_digest(user, 1.year.ago, top_order: true).should be_blank
    end

    it "doesn't return category topics" do
      Fabricate(:category)
      Topic.for_digest(user, 1.year.ago, top_order: true).should be_blank
    end

    it "returns regular topics" do
      topic = Fabricate(:topic)
      Topic.for_digest(user, 1.year.ago, top_order: true).should == [topic]
    end

  end

  describe 'secured' do
    it 'can remove secure groups' do
      category = Fabricate(:category, read_restricted: true)
      Fabricate(:topic, category: category)

      Topic.secured(Guardian.new(nil)).count.should == 0
      Topic.secured(Guardian.new(Fabricate(:admin))).count.should == 2

      # for_digest

      Topic.for_digest(Fabricate(:user), 1.year.ago).count.should == 0
      Topic.for_digest(Fabricate(:admin), 1.year.ago).count.should == 1
    end
  end

  describe '#secure_category?' do
    let(:category){ Category.new }

    it "is true if the category is secure" do
      category.stubs(:read_restricted).returns(true)
      Topic.new(:category => category).should be_read_restricted_category
    end

    it "is false if the category is not secure" do
      category.stubs(:read_restricted).returns(false)
      Topic.new(:category => category).should_not be_read_restricted_category
    end

    it "is false if there is no category" do
      Topic.new(:category => nil).should_not be_read_restricted_category
    end
  end

  describe 'trash!' do
    context "its category's topic count" do
      let(:moderator) { Fabricate(:moderator) }
      let(:category) { Fabricate(:category) }

      it "subtracts 1 if topic is being deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.trash!(moderator) }.to change { category.reload.topic_count }.by(-1)
      end

      it "doesn't subtract 1 if topic is already deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.trash!(moderator) }.to_not change { category.reload.topic_count }
      end
    end
  end

  describe 'recover!' do
    context "its category's topic count" do
      let(:category) { Fabricate(:category) }

      it "adds 1 if topic is deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.recover! }.to change { category.reload.topic_count }.by(1)
      end

      it "doesn't add 1 if topic is not deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.recover! }.to_not change { category.reload.topic_count }
      end
    end
  end

  it "limits new users to max_topics_in_first_day and max_posts_in_first_day" do
    SiteSetting.stubs(:max_topics_in_first_day).returns(1)
    SiteSetting.stubs(:max_replies_in_first_day).returns(1)
    SiteSetting.stubs(:client_settings_json).returns(SiteSetting.client_settings_json_uncached)
    RateLimiter.stubs(:rate_limit_create_topic).returns(100)
    RateLimiter.stubs(:disabled?).returns(false)

    start = Time.now.tomorrow.beginning_of_day

    freeze_time(start)

    user = Fabricate(:user)
    topic_id = create_post(user: user).topic_id

    freeze_time(start + 10.minutes)
    lambda {
      create_post(user: user)
    }.should raise_exception

    freeze_time(start + 20.minutes)
    create_post(user: user, topic_id: topic_id)

    freeze_time(start + 30.minutes)

    lambda {
      create_post(user: user, topic_id: topic_id)
    }.should raise_exception
  end

  describe ".count_exceeds_minimun?" do
    before { SiteSetting.stubs(:minimum_topics_similar).returns(20) }

    context "when Topic count is geater than minimum_topics_similar" do
      it "should be true" do
        Topic.stubs(:count).returns(30)
        expect(Topic.count_exceeds_minimum?).to be_truthy
      end
    end

    context "when topic's count is less than minimum_topics_similar" do
      it "should be false" do
        Topic.stubs(:count).returns(10)
        expect(Topic.count_exceeds_minimum?).to_not be_truthy
      end
    end

  end

  describe "calculate_avg_time" do
    it "does not explode" do
      Topic.calculate_avg_time
      Topic.calculate_avg_time(1.day.ago)
    end
  end

  describe "expandable_first_post?" do
    let(:topic) { Fabricate.build(:topic) }

    before do
      SiteSetting.stubs(:embeddable_host).returns("http://eviltrout.com")
      SiteSetting.stubs(:embed_truncate?).returns(true)
      topic.stubs(:has_topic_embed?).returns(true)
    end

    it "is true with the correct settings and topic_embed" do
      topic.expandable_first_post?.should == true
    end

    it "is false if embeddable_host is blank" do
      SiteSetting.stubs(:embeddable_host).returns(nil)
      topic.expandable_first_post?.should == false
    end

    it "is false if embed_truncate? is false" do
      SiteSetting.stubs(:embed_truncate?).returns(false)
      topic.expandable_first_post?.should == false
    end

    it "is false if has_topic_embed? is false" do
      topic.stubs(:has_topic_embed?).returns(false)
      topic.expandable_first_post?.should == false
    end
  end

  it "has custom fields" do
    topic = Fabricate(:topic)
    topic.custom_fields["a"].should == nil

    topic.custom_fields["bob"] = "marley"
    topic.custom_fields["jack"] = "black"
    topic.save

    topic = Topic.find(topic.id)
    topic.custom_fields.should == {"bob" => "marley", "jack" => "black"}
  end

  it "doesn't validate the title again if it isn't changing" do
    SiteSetting.stubs(:min_topic_title_length).returns(5)
    topic = Fabricate(:topic, title: "Short")
    topic.should be_valid

    SiteSetting.stubs(:min_topic_title_length).returns(15)
    topic.last_posted_at = 1.minute.ago
    topic.save.should == true
  end
end
