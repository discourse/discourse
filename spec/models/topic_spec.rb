# encoding: utf-8

require 'spec_helper'
require_dependency 'post_destroyer'

describe Topic do

  let(:now) { Time.zone.local(2013,11,20,8,0) }

  it { is_expected.to validate_presence_of :title }

  it { is_expected.to rate_limit }

  context '#visible_post_types' do
    let(:types) { Post.types }

    it "returns the appropriate types for anonymous users" do
      post_types = Topic.visible_post_types

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to_not include(types[:whisper])
    end

    it "returns the appropriate types for regular users" do
      post_types = Topic.visible_post_types(Fabricate.build(:user))

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to_not include(types[:whisper])
    end

    it "returns the appropriate types for staff users" do
      post_types = Topic.visible_post_types(Fabricate.build(:moderator))

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to include(types[:whisper])
    end
  end

  context 'slug' do
    let(:title) { "hello world topic" }
    let(:slug) { "hello-world-topic" }
    context 'encoded generator' do
      before { SiteSetting.slug_generation_method = 'encoded' }
      after { SiteSetting.slug_generation_method = 'ascii' }

      it "returns a Slug for a title" do
        Slug.expects(:for).with(title).returns(slug)
        expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
      end

      context 'for cjk characters' do
        let(:title) { "熱帶風暴畫眉" }
        let(:slug) { "熱帶風暴畫眉" }
        it "returns encoded Slug for a title" do
          Slug.expects(:for).with(title).returns(slug)
          expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
        end
      end

      context 'for numbers' do
        let(:title) { "123456789" }
        let(:slug) { "topic" }
        it 'generates default slug' do
          Slug.expects(:for).with(title).returns("topic")
          expect(Fabricate.build(:topic, title: title).slug).to eq("topic")
        end
      end
    end

    context 'none generator' do
      before { SiteSetting.slug_generation_method = 'none' }
      after { SiteSetting.slug_generation_method = 'ascii' }
      let(:title) { "熱帶風暴畫眉" }
      let(:slug) { "topic" }

      it "returns a Slug for a title" do
        Slug.expects(:for).with(title).returns('topic')
        expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
      end
    end

    context '#ascii_generator' do
      before { SiteSetting.slug_generation_method = 'ascii' }
      it "returns a Slug for a title" do
        Slug.expects(:for).with(title).returns(slug)
        expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
      end

      context 'for cjk characters' do
        let(:title) { "熱帶風暴畫眉" }
        let(:slug) { 'topic' }
        it "returns 'topic' when the slug is empty (say, non-latin characters)" do
          Slug.expects(:for).with(title).returns("topic")
          expect(Fabricate.build(:topic, title: title).slug).to eq("topic")
        end
      end
    end
  end

  context "updating a title to be shorter" do
    let!(:topic) { Fabricate(:topic) }

    it "doesn't update it to be shorter due to cleaning using TextCleaner" do
      topic.title = 'unread    glitch'
      expect(topic.save).to eq(false)
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
        expect(new_topic).not_to be_valid
      end

      it "won't allow another topic with an upper case title to be created" do
        new_topic.title = new_topic.title.upcase
        expect(new_topic).not_to be_valid
      end

      it "allows it when the topic is deleted" do
        topic.destroy
        expect(new_topic).to be_valid
      end

      it "allows a private message to be created with the same topic" do
        new_topic.archetype = Archetype.private_message
        expect(new_topic).to be_valid
      end
    end

    context "when duplicates are allowed" do
      before do
        SiteSetting.expects(:allow_duplicate_topic_titles?).returns(true)
      end

      it "will allow another topic to be created with the same name" do
        expect(new_topic).to be_valid
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
      expect(topic_script.fancy_title).to eq("Topic with &lt;script&gt;alert(&lsquo;title&rsquo;)&lt;/script&gt; script in its title")
    end

    it "escapes bold contents" do
      expect(topic_bold.fancy_title).to eq("Topic with &lt;b&gt;bold&lt;/b&gt; text in its title")
    end

    it "escapes image contents" do
      expect(topic_image.fancy_title).to eq("Topic with &lt;img src=&lsquo;something&rsquo;&gt; image in its title")
    end

  end

  context 'fancy title' do
    let(:topic) { Fabricate.build(:topic, title: "\"this topic\" -- has ``fancy stuff''" ) }

    context 'title_fancy_entities disabled' do
      before do
        SiteSetting.stubs(:title_fancy_entities).returns(false)
      end

      it "doesn't add entities to the title" do
        expect(topic.fancy_title).to eq("&quot;this topic&quot; -- has ``fancy stuff&#39;&#39;")
      end
    end

    context 'title_fancy_entities enabled' do
      before do
        SiteSetting.stubs(:title_fancy_entities).returns(true)
      end

      it "converts the title to have fancy entities" do
        expect(topic.fancy_title).to eq("&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;")
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
        expect(topic).not_to be_valid
        expect(topic.errors[:category_id]).to be_present
      end

      it "allows PMs" do
        topic = Fabricate.build(:topic, category: nil, archetype: Archetype.private_message)
        expect(topic).to be_valid
      end

      it 'passes for topics with a category' do
        expect(Fabricate.build(:topic, category: Fabricate(:category))).to be_valid
      end
    end

    context 'allow_uncategorized_topics is true' do
      before do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
      end

      it "passes for topics with nil category" do
        expect(Fabricate.build(:topic, category: nil)).to be_valid
      end

      it 'passes for topics with a category' do
        expect(Fabricate.build(:topic, category: Fabricate(:category))).to be_valid
      end
    end
  end


  context 'similar_to' do

    it 'returns blank with nil params' do
      expect(Topic.similar_to(nil, nil)).to be_blank
    end

    context "with a category definition" do
      let!(:category) { Fabricate(:category) }

      it "excludes the category definition topic from similar_to" do
        expect(Topic.similar_to('category definition for', "no body")).to be_blank
      end
    end

    context 'with a similar topic' do
      let!(:topic) {
        ActiveRecord::Base.observers.enable :search_observer
        post = create_post(title: "Evil trout is the dude who posted this topic")
        post.topic
      }

      it 'returns the similar topic if the title is similar' do
        expect(Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?")).to eq([topic])
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
      expect(topic.post_numbers).to eq([1, 2, 3])
      p2.destroy
      topic.reload
      expect(topic.post_numbers).to eq([1, 3])
    end

  end


  context 'private message' do
    let(:coding_horror) { User.find_by(username: "CodingHorror") }
    let(:evil_trout) { Fabricate(:evil_trout) }
    let(:topic) { Fabricate(:private_message_topic) }

    it "should integrate correctly" do
      expect(Guardian.new(topic.user).can_see?(topic)).to eq(true)
      expect(Guardian.new.can_see?(topic)).to eq(false)
      expect(Guardian.new(evil_trout).can_see?(topic)).to eq(false)
      expect(Guardian.new(coding_horror).can_see?(topic)).to eq(true)
      expect(TopicQuery.new(evil_trout).list_latest.topics).not_to include(topic)

      # invites
      expect(topic.invite(topic.user, 'duhhhhh')).to eq(false)
    end

    context 'invite' do

      context 'existing user' do
        let(:walter) { Fabricate(:walter_white) }

        context 'by username' do

          it 'adds and removes walter to the allowed users' do
            expect(topic.invite(topic.user, walter.username)).to eq(true)
            expect(topic.allowed_users.include?(walter)).to eq(true)

            expect(topic.remove_allowed_user(walter.username)).to eq(true)
            topic.reload
            expect(topic.allowed_users.include?(walter)).to eq(false)
          end

          it 'creates a notification' do
            expect { topic.invite(topic.user, walter.username) }.to change(Notification, :count)
          end
        end

        context 'by email' do

          it 'adds user correctly' do
            expect {
              expect(topic.invite(topic.user, walter.email)).to eq(true)
            }.to change(Notification, :count)
            expect(topic.allowed_users.include?(walter)).to eq(true)
          end

        end
      end

    end

    context "user actions" do
      let(:actions) { topic.user.user_actions }

      it "should set up actions correctly" do
        ActiveRecord::Base.observers.enable :all

        expect(actions.map{|a| a.action_type}).not_to include(UserAction::NEW_TOPIC)
        expect(actions.map{|a| a.action_type}).to include(UserAction::NEW_PRIVATE_MESSAGE)
        expect(coding_horror.user_actions.map{|a| a.action_type}).to include(UserAction::GOT_PRIVATE_MESSAGE)
      end

    end

  end

  it "rate limits topic invitations" do
    SiteSetting.stubs(:max_topic_invitations_per_day).returns(2)
    RateLimiter.stubs(:disabled?).returns(false)
    RateLimiter.clear_all!

    start = Time.now.tomorrow.beginning_of_day
    freeze_time(start)

    user = Fabricate(:user)
    topic = Fabricate(:topic)

    freeze_time(start + 10.minutes)
    topic.invite(topic.user, user.username)

    freeze_time(start + 20.minutes)
    topic.invite(topic.user, "walter@white.com")

    freeze_time(start + 30.minutes)

    expect {
      topic.invite(topic.user, "user@example.com")
    }.to raise_exception
  end

  context 'bumping topics' do

    before do
      @topic = Fabricate(:topic, bumped_at: 1.year.ago)
    end

    it 'updates the bumped_at field when a new post is made' do
      expect(@topic.bumped_at).to be_present
      expect {
        create_post(topic: @topic, user: @topic.user)
        @topic.reload
      }.to change(@topic, :bumped_at)
    end

    context 'editing posts' do
      before do
        @earlier_post = Fabricate(:post, topic: @topic, user: @topic.user)
        @last_post = Fabricate(:post, topic: @topic, user: @topic.user)
        @topic.reload
      end

      it "doesn't bump the topic on an edit to the last post that doesn't result in a new version" do
        expect {
          SiteSetting.expects(:ninja_edit_window).returns(5.minutes)
          @last_post.revise(@last_post.user, { raw: 'updated contents' }, revised_at: @last_post.created_at + 10.seconds)
          @topic.reload
        }.not_to change(@topic, :bumped_at)
      end

      it "bumps the topic when a new version is made of the last post" do
        expect {
          @last_post.revise(Fabricate(:moderator), { raw: 'updated contents' })
          @topic.reload
        }.to change(@topic, :bumped_at)
      end

      it "doesn't bump the topic when a post that isn't the last post receives a new version" do
        expect {
          @earlier_post.revise(Fabricate(:moderator), { raw: 'updated contents' })
          @topic.reload
        }.not_to change(@topic, :bumped_at)
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
      expect(@mod_post).to be_present
      expect(@mod_post.post_type).to eq(Post.types[:moderator_action])
      expect(@mod_post.post_number).to eq(999)
      expect(@mod_post.sort_order).to eq(999)
      expect(@topic.topic_links.count).to eq(1)
      @topic.reload
      expect(@topic.moderator_posts_count).to eq(1)
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
          expect(@topic).not_to be_visible
          expect(@topic.moderator_posts_count).to eq(1)
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :visible, false
          @topic.update_status('visible', true, @user)
          @topic.reload
        end

        it 'should be visible with correct counts' do
          expect(@topic).to be_visible
          expect(@topic.moderator_posts_count).to eq(1)
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
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
          expect(@topic.pinned_at).to be_blank
          expect(@topic.moderator_posts_count).to eq(1)
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :pinned_at, nil
          @topic.update_status('pinned', true, @user)
          @topic.reload
        end

        it 'should enable correctly' do
          expect(@topic.pinned_at).to be_present
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
          expect(@topic.moderator_posts_count).to eq(1)
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
          expect(@topic).not_to be_archived
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
          expect(@topic.moderator_posts_count).to eq(1)
        end
      end

      context 'enable' do
        before do
          @topic.update_attribute :archived, false
          @topic.update_status('archived', true, @user)
          @topic.reload
        end

        it 'should be archived' do
          expect(@topic).to be_archived
          expect(@topic.moderator_posts_count).to eq(1)
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
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
          expect(@topic).not_to be_closed
          expect(@topic.moderator_posts_count).to eq(1)
          expect(@topic.bumped_at.to_f).not_to eq(@original_bumped_at)
        end

      end

      context 'enable' do
        before do
          @topic.update_attribute :closed, false
          @topic.update_status(status, true, @user)
          @topic.reload
        end

        it 'should be closed' do
          expect(@topic).to be_closed
          expect(@topic.bumped_at.to_f).to eq(@original_bumped_at)
          expect(@topic.moderator_posts_count).to eq(1)
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

  describe "banner" do

    let(:topic) { Fabricate(:topic) }
    let(:user) { topic.user }
    let(:banner) { { html: "<p>BANNER</p>", url: topic.url, key: topic.id } }

    before { topic.stubs(:banner).returns(banner) }

    describe "make_banner!" do

      it "changes the topic archetype to 'banner'" do
        messages = MessageBus.track_publish do
          topic.make_banner!(user)
          expect(topic.archetype).to eq(Archetype.banner)
        end

        channels = messages.map(&:channel)
        expect(channels).to include('/site/banner')
        expect(channels).to include('/distributed_hash')
      end

      it "ensures only one banner topic at all time" do
        _banner_topic = Fabricate(:banner_topic)
        expect(Topic.where(archetype: Archetype.banner).count).to eq(1)

        topic.make_banner!(user)
        expect(Topic.where(archetype: Archetype.banner).count).to eq(1)
      end

    end

    describe "remove_banner!" do

      it "resets the topic archetype" do
        topic.expects(:add_moderator_post)
        MessageBus.expects(:publish).with("/site/banner", nil)
        topic.remove_banner!(user)
        expect(topic.archetype).to eq(Archetype.default)
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
      expect(@topic.last_post_user_id).to eq(@user.id)
    end

    context 'after a second post' do
      before do
        @second_user = Fabricate(:coding_horror)
        @new_post = create_post(topic: @topic, user: @second_user)
        @topic.reload
      end

      it 'updates the last_post_user_id to the second_user' do
        expect(@topic.last_post_user_id).to eq(@second_user.id)
        expect(@topic.last_posted_at.to_i).to eq(@new_post.created_at.to_i)
        topic_user = @second_user.topic_users.find_by(topic_id: @topic.id)
        expect(topic_user.posted?).to eq(true)
      end

    end
  end

  describe 'with category' do

    before do
      @category = Fabricate(:category)
    end

    it "should not increase the topic_count with no category" do
      expect { Fabricate(:topic, user: @category.user); @category.reload }.not_to change(@category, :topic_count)
    end

    it "should increase the category's topic_count" do
      expect { Fabricate(:topic, user: @category.user, category_id: @category.id); @category.reload }.to change(@category, :topic_count).by(1)
    end
  end

  describe 'meta data' do
    let(:topic) { Fabricate(:topic, meta_data: {'hello' => 'world'}) }

    it 'allows us to create a topic with meta data' do
      expect(topic.meta_data['hello']).to eq('world')
    end

    context 'updating' do

      context 'existing key' do
        before do
          topic.update_meta_data('hello' => 'bane')
        end

        it 'updates the key' do
          expect(topic.meta_data['hello']).to eq('bane')
        end
      end

      context 'new key' do
        before do
          topic.update_meta_data('city' => 'gotham')
        end

        it 'adds the new key' do
          expect(topic.meta_data['city']).to eq('gotham')
          expect(topic.meta_data['hello']).to eq('world')
        end

      end

      context 'new key' do
        before do
          topic.update_meta_data('other' => 'key')
          topic.save!
        end

        it "can be loaded" do
          expect(Topic.find(topic.id).meta_data["other"]).to eq("key")
        end

        it "is in sync with custom_fields" do
          expect(Topic.find(topic.id).custom_fields["other"]).to eq("key")
        end
      end


    end

  end

  describe 'after create' do

    let(:topic) { Fabricate(:topic) }

    it 'is a regular topic by default' do
      expect(topic.archetype).to eq(Archetype.default)
      expect(topic.has_summary).to eq(false)
      expect(topic.percent_rank).to eq(1.0)
      expect(topic).to be_visible
      expect(topic.pinned_at).to be_blank
      expect(topic).not_to be_closed
      expect(topic).not_to be_archived
      expect(topic.moderator_posts_count).to eq(0)
    end

    context 'post' do
      let(:post) { Fabricate(:post, topic: topic, user: topic.user) }

      it 'has the same archetype as the topic' do
        expect(post.archetype).to eq(topic.archetype)
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
       expect { @topic.change_category_to_id(@topic.category.id); @category.reload }.not_to change(@category, :topic_count)
      end

      describe 'changed category' do
        before do
          @topic.change_category_to_id(@category.id)
          @category.reload
        end

        it 'changes the category' do
          expect(@topic.category).to eq(@category)
          expect(@category.topic_count).to eq(1)
        end

      end

      it "doesn't change the category when it can't be found" do
        @topic.change_category_to_id(12312312)
        expect(@topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end
    end

    describe 'with a previous category' do
      before do
        @topic.change_category_to_id(@category.id)
        @topic.reload
        @category.reload
      end

      it 'increases the topic_count' do
        expect(@category.topic_count).to eq(1)
      end

      it "doesn't change the topic_count when the value doesn't change" do
        expect { @topic.change_category_to_id(@category.id); @category.reload }.not_to change(@category, :topic_count)
      end

      it "doesn't reset the category when given a name that doesn't exist" do
        @topic.change_category_to_id(55556)
        expect(@topic.category_id).to be_present
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
          expect(@new_category.topic_count).to eq(1)
        end

        it "should lower the original category's topic count" do
          expect(@category.topic_count).to eq(0)
        end
      end

      context 'when allow_uncategorized_topics is false' do
        before do
          SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
        end

        let!(:topic) { Fabricate(:topic, category: Fabricate(:category)) }

        it 'returns false' do
          expect(topic.change_category_to_id(nil)).to eq(false) # don't use "== false" here because it would also match nil
        end
      end

      describe 'when the category exists' do
        before do
          @topic.change_category_to_id(nil)
          @category.reload
        end

        it "resets the category" do
          expect(@topic.category_id).to eq(SiteSetting.uncategorized_category_id)
          expect(@category.topic_count).to eq(0)
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
        expect(Topic.by_newest).to eq([c,b,d,a])
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
        expect(Topic.created_since(now)).not_to include a
        expect(Topic.created_since(now)).not_to include b
        expect(Topic.created_since(now)).not_to include c
        expect(Topic.created_since(now)).to include d
        expect(Topic.created_since(now)).to include e
      end
    end

    describe '#visible' do
      it 'returns topics set as visible' do
        a = Fabricate(:topic, visible: false)
        b = Fabricate(:topic, visible: true)
        c = Fabricate(:topic, visible: true)
        expect(Topic.visible).not_to include a
        expect(Topic.visible).to include b
        expect(Topic.visible).to include c
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
          topic.set_auto_close(7, {by_user: topic_closer}).save
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
          expect(topic.save).to eq(true)
        end
      end

      it 'when auto_close_at and auto_closer_user_id are set, it queues a job to close the topic' do
        Timecop.freeze(now) do
          topic  = Fabricate(:topic)
          closer = Fabricate(:admin)
          Jobs.expects(:enqueue_at).with(12.hours.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: closer.id))
          topic.auto_close_at = 12.hours.from_now
          topic.auto_close_user = closer
          expect(topic.save).to eq(true)
        end
      end

      it 'when auto_close_at is removed, it cancels the job to close the topic' do
        Jobs.stubs(:enqueue_at).returns(true)
        topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
        Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
        topic.auto_close_at = nil
        expect(topic.save).to eq(true)
        expect(topic.auto_close_user).to eq(nil)
      end

      it 'when auto_close_user is removed, it updates the job' do
        Timecop.freeze(now) do
          Jobs.stubs(:enqueue_at).with(1.day.from_now, :close_topic, anything).returns(true)
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now, auto_close_user: Fabricate(:admin))
          Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
          Jobs.expects(:enqueue_at).with(1.day.from_now, :close_topic, has_entries(topic_id: topic.id, user_id: topic.user_id))
          topic.auto_close_user = nil
          expect(topic.save).to eq(true)
        end
      end

      it 'when auto_close_at value is changed, it reschedules the job' do
        Timecop.freeze(now) do
          Jobs.stubs(:enqueue_at).returns(true)
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
          Jobs.expects(:cancel_scheduled_job).with(:close_topic, {topic_id: topic.id})
          Jobs.expects(:enqueue_at).with(3.days.from_now, :close_topic, has_entry(topic_id: topic.id))
          topic.auto_close_at = 3.days.from_now
          expect(topic.save).to eq(true)
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
          expect(topic.save).to eq(true)
        end
      end

      it 'when auto_close_at and auto_close_user_id are not changed, it should not schedule another CloseTopic job' do
        Timecop.freeze(now) do
          Jobs.expects(:enqueue_at).with(1.day.from_now, :close_topic, has_key(:topic_id)).once.returns(true)
          Jobs.expects(:cancel_scheduled_job).never
          topic = Fabricate(:topic, auto_close_at: 1.day.from_now)
          topic.title = 'A new title that is long enough'
          expect(topic.save).to eq(true)
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
          expect(topic.closed).to eq(false)

          Timecop.freeze(24.hours.from_now) do
            Topic.auto_close
            topic.reload
            expect(topic.closed).to eq(true)
          end

        end
      end
    end
  end

  describe 'set_auto_close' do
    let(:topic)         { Fabricate.build(:topic) }
    let(:closing_topic) { Fabricate.build(:topic, auto_close_hours: 5, auto_close_at: 5.hours.from_now, auto_close_started_at: 5.hours.from_now) }
    let(:admin)         { Fabricate.build(:user, id: 123) }
    let(:trust_level_4) { Fabricate.build(:trust_level_4) }

    before { Discourse.stubs(:system_user).returns(admin) }

    it 'can take a number of hours as an integer' do
      Timecop.freeze(now) do
        topic.set_auto_close(72, {by_user: admin})
        expect(topic.auto_close_at).to eq(3.days.from_now)
      end
    end

    it 'can take a number of hours as an integer, with timezone offset' do
      Timecop.freeze(now) do
        topic.set_auto_close(72, {by_user: admin, timezone_offset: 240})
        expect(topic.auto_close_at).to eq(3.days.from_now)
      end
    end

    it 'can take a number of hours as a string' do
      Timecop.freeze(now) do
        topic.set_auto_close('18', {by_user: admin})
        expect(topic.auto_close_at).to eq(18.hours.from_now)
      end
    end

    it 'can take a number of hours as a string, with timezone offset' do
      Timecop.freeze(now) do
        topic.set_auto_close('18', {by_user: admin, timezone_offset: 240})
        expect(topic.auto_close_at).to eq(18.hours.from_now)
      end
    end

    it "can take a time later in the day" do
      Timecop.freeze(now) do
        topic.set_auto_close('13:00', {by_user: admin})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,20,13,0))
      end
    end

    it "can take a time later in the day, with timezone offset" do
      Timecop.freeze(now) do
        topic.set_auto_close('13:00', {by_user: admin, timezone_offset: 240})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,20,17,0))
      end
    end

    it "can take a time for the next day" do
      Timecop.freeze(now) do
        topic.set_auto_close('5:00', {by_user: admin})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,21,5,0))
      end
    end

    it "can take a time for the next day, with timezone offset" do
      Timecop.freeze(now) do
        topic.set_auto_close('1:00', {by_user: admin, timezone_offset: 240})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,21,5,0))
      end
    end

    it "can take a timestamp for a future time" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-22 5:00', {by_user: admin})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,22,5,0))
      end
    end

    it "can take a timestamp for a future time, with timezone offset" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-22 5:00', {by_user: admin, timezone_offset: 240})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,22,9,0))
      end
    end

    it "sets a validation error when given a timestamp in the past" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-19 5:00', {by_user: admin})
        expect(topic.auto_close_at).to eq(Time.zone.local(2013,11,19,5,0))
        expect(topic.errors[:auto_close_at]).to be_present
      end
    end

    it "can take a timestamp with timezone" do
      Timecop.freeze(now) do
        topic.set_auto_close('2013-11-25T01:35:00-08:00', {by_user: admin})
        expect(topic.auto_close_at).to eq(Time.utc(2013,11,25,9,35))
      end
    end

    it 'sets auto_close_user to given user if it is a staff or TL4 user' do
      topic.set_auto_close(3, {by_user: admin})
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to given user if it is a TL4 user' do
      topic.set_auto_close(3, {by_user: trust_level_4})
      expect(topic.auto_close_user_id).to eq(trust_level_4.id)
    end

    it 'sets auto_close_user to system user if given user is not staff or a TL4 user' do
      topic.set_auto_close(3, {by_user: Fabricate.build(:user, id: 444)})
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to system user if user is not given and topic creator is not staff nor TL4 user' do
      topic.set_auto_close(3)
      expect(topic.auto_close_user_id).to eq(admin.id)
    end

    it 'sets auto_close_user to topic creator if it is a staff user' do
      staff_topic = Fabricate.build(:topic, user: Fabricate.build(:admin, id: 999))
      staff_topic.set_auto_close(3)
      expect(staff_topic.auto_close_user_id).to eq(999)
    end

    it 'sets auto_close_user to topic creator if it is a TL4 user' do
      tl4_topic = Fabricate.build(:topic, user: Fabricate.build(:trust_level_4, id: 998))
      tl4_topic.set_auto_close(3)
      expect(tl4_topic.auto_close_user_id).to eq(998)
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
      expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
    end

    it "doesn't return category topics" do
      Fabricate(:category)
      expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
    end

    it "returns regular topics" do
      topic = Fabricate(:topic)
      expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
    end

    it "doesn't return topics from muted categories" do
      user = Fabricate(:user)
      category = Fabricate(:category)
      Fabricate(:topic, category: category)

      CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[:muted], category.id)

      expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
    end

    it "doesn't return topics from TL0 users" do
      new_user = Fabricate(:user, trust_level: 0)
      Fabricate(:topic, user_id: new_user.id)

      expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
    end

  end

  describe 'secured' do
    it 'can remove secure groups' do
      category = Fabricate(:category, read_restricted: true)
      Fabricate(:topic, category: category)

      expect(Topic.secured(Guardian.new(nil)).count).to eq(0)
      expect(Topic.secured(Guardian.new(Fabricate(:admin))).count).to eq(2)

      # for_digest

      expect(Topic.for_digest(Fabricate(:user), 1.year.ago).count).to eq(0)
      expect(Topic.for_digest(Fabricate(:admin), 1.year.ago).count).to eq(1)
    end
  end

  describe '#listable_count_per_day' do
    before(:each) do
      Timecop.freeze
      Fabricate(:topic)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 2.days.ago)
      Fabricate(:topic, created_at: 4.days.ago)
    end
    after(:each) do
      Timecop.return
    end
    let(:listable_topics_count_per_day) { {1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1 } }

    it 'collect closed interval listable topics count' do
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).to include(listable_topics_count_per_day)
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).not_to include({4.days.ago.to_date => 1})
    end
  end

  describe '#secure_category?' do
    let(:category){ Category.new }

    it "is true if the category is secure" do
      category.stubs(:read_restricted).returns(true)
      expect(Topic.new(:category => category)).to be_read_restricted_category
    end

    it "is false if the category is not secure" do
      category.stubs(:read_restricted).returns(false)
      expect(Topic.new(:category => category)).not_to be_read_restricted_category
    end

    it "is false if there is no category" do
      expect(Topic.new(:category => nil)).not_to be_read_restricted_category
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
    RateLimiter.clear_all!

    start = Time.now.tomorrow.beginning_of_day

    freeze_time(start)

    user = Fabricate(:user)
    topic_id = create_post(user: user).topic_id

    freeze_time(start + 10.minutes)
    expect {
      create_post(user: user)
    }.to raise_exception

    freeze_time(start + 20.minutes)
    create_post(user: user, topic_id: topic_id)

    freeze_time(start + 30.minutes)

    expect {
      create_post(user: user, topic_id: topic_id)
    }.to raise_exception
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

    it "is false if embeddable_host is blank" do
      expect(topic.expandable_first_post?).to eq(false)
    end

    describe 'with an emeddable host' do
      before do
        Fabricate(:embeddable_host)
        SiteSetting.embed_truncate = true
        topic.stubs(:has_topic_embed?).returns(true)
      end

      it "is true with the correct settings and topic_embed" do
        expect(topic.expandable_first_post?).to eq(true)
      end
      it "is false if embed_truncate? is false" do
        SiteSetting.embed_truncate = false
        expect(topic.expandable_first_post?).to eq(false)
      end

      it "is false if has_topic_embed? is false" do
        topic.stubs(:has_topic_embed?).returns(false)
        expect(topic.expandable_first_post?).to eq(false)
      end
    end

  end

  it "has custom fields" do
    topic = Fabricate(:topic)
    expect(topic.custom_fields["a"]).to eq(nil)

    topic.custom_fields["bob"] = "marley"
    topic.custom_fields["jack"] = "black"
    topic.save

    topic = Topic.find(topic.id)
    expect(topic.custom_fields).to eq({"bob" => "marley", "jack" => "black"})
  end

  it "doesn't validate the title again if it isn't changing" do
    SiteSetting.stubs(:min_topic_title_length).returns(5)
    topic = Fabricate(:topic, title: "Short")
    expect(topic).to be_valid

    SiteSetting.stubs(:min_topic_title_length).returns(15)
    topic.last_posted_at = 1.minute.ago
    expect(topic.save).to eq(true)
  end

  context 'invite by group manager' do
    let(:group_manager) { Fabricate(:user) }
    let(:group) { Fabricate(:group).tap { |g| g.add(group_manager); g.appoint_manager(group_manager) } }
    let(:private_category)  { Fabricate(:private_category, group: group) }
    let(:group_private_topic) { Fabricate(:topic, category: private_category, user: group_manager) }

    context 'to an email' do
      let(:randolph) { 'randolph@duke.ooo' }

      it "should attach group to the invite" do
        invite = group_private_topic.invite(group_manager, randolph)
        expect(invite.groups).to eq([group])
      end
    end

    # should work for an existing user - give access, send notification
    context 'to an existing user' do
      let(:walter) { Fabricate(:walter_white) }

      it "should add user to the group" do
        expect(Guardian.new(walter).can_see?(group_private_topic)).to be_falsey
        invite = group_private_topic.invite(group_manager, walter.email)
        expect(invite).to be_nil
        expect(walter.groups).to include(group)
        expect(Guardian.new(walter).can_see?(group_private_topic)).to be_truthy
      end
    end

    context 'to a previously-invited user' do

    end
  end
end
