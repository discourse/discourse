# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'
require_dependency 'post_destroyer'

describe Topic do
  let(:now) { Time.zone.local(2013, 11, 20, 8, 0) }
  fab!(:user) { Fabricate(:user) }
  fab!(:another_user) { Fabricate(:user) }
  fab!(:trust_level_2) { Fabricate(:user, trust_level: TrustLevel[2]) }

  context 'validations' do
    let(:topic) { Fabricate.build(:topic) }

    context "#featured_link" do
      describe 'when featured_link contains more than a URL' do
        it 'should not be valid' do
          topic.featured_link = 'http://meta.discourse.org TEST'
          expect(topic).to_not be_valid
        end
      end

      describe 'when featured_link is a valid URL' do
        it 'should be valid' do
          topic.featured_link = 'http://meta.discourse.org'
          expect(topic).to be_valid
        end
      end
    end

    context "#title" do
      it { is_expected.to validate_presence_of :title }

      describe 'censored words' do
        after do
          $redis.flushall
        end

        describe 'when title contains censored words' do
          it 'should not be valid' do
            ['pineapple', 'pen'].each { |w| Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor]) }

            topic.title = 'pen PinEapple apple pen is a complete sentence'

            expect(topic).to_not be_valid

            expect(topic.errors.full_messages.first).to include(I18n.t(
              'errors.messages.contains_censored_words', censored_words: 'pen, pineapple'
            ))
          end
        end

        describe 'titles with censored words not on boundaries' do
          it "should be valid" do
            Fabricate(:watched_word, word: 'apple', action: WatchedWord.actions[:censor])
            topic.title = "Pineapples are great fruit! Applebee's is a great restaurant"
            expect(topic).to be_valid
          end
        end

        describe 'when title does not contain censored words' do
          it 'should be valid' do
            topic.title = 'The cake is a lie'

            expect(topic).to be_valid
          end
        end

        describe 'escape special characters in censored words' do
          before do
            ['co(onut', 'coconut', 'a**le'].each do |w|
              Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor])
            end
          end

          it 'should not be valid' do
            topic.title = "I have a co(onut a**le"

            expect(topic.valid?).to eq(false)

            expect(topic.errors.full_messages.first).to include(I18n.t(
              'errors.messages.contains_censored_words',
              censored_words: 'co(onut, a**le'
            ))
          end
        end
      end
    end
  end

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
    context 'encoded generator' do
      before { SiteSetting.slug_generation_method = 'encoded' }

      context 'with ascii letters' do
        let!(:title) { "hello world topic" }
        let!(:slug) { "hello-world-topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns a Slug for a title" do
          expect(topic.title).to eq(title)
          expect(topic.slug).to eq(slug)
        end
      end

      context 'for cjk characters' do
        let!(:title) { "熱帶風暴畫眉" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns encoded Slug for a title" do
          expect(topic.title).to eq(title)
          expect(topic.slug).to eq(title)
        end
      end

      context 'for numbers' do
        let!(:title) { "123456789" }
        let!(:slug) { "topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it 'generates default slug' do
          Slug.expects(:for).with(title).returns("topic")
          expect(Fabricate.build(:topic, title: title).slug).to eq("topic")
        end
      end
    end

    context 'none generator' do
      let!(:title) { "熱帶風暴畫眉" }
      let!(:slug) { "topic" }
      let!(:topic) { Fabricate.build(:topic, title: title) }

      before { SiteSetting.slug_generation_method = 'none' }

      it "returns a Slug for a title" do
        Slug.expects(:for).with(title).returns('topic')
        expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
      end
    end

    context '#ascii_generator' do
      before { SiteSetting.slug_generation_method = 'ascii' }

      context 'with ascii letters' do
        let!(:title) { "hello world topic" }
        let!(:slug) { "hello-world-topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns a Slug for a title" do
          Slug.expects(:for).with(title).returns(slug)
          expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
        end
      end

      context 'for cjk characters' do
        let!(:title) { "熱帶風暴畫眉" }
        let!(:slug) { 'topic' }
        let!(:topic) { Fabricate.build(:topic, title: title) }

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
      SiteSetting.min_topic_title_length = 15
      SiteSetting.min_personal_message_title_length = 3
    end

    it 'allows shorter titles' do
      pm = Fabricate.build(:private_message_topic, title: 'a' * SiteSetting.min_personal_message_title_length)
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
      build(:topic, title: title).tap { |t| t.valid? }
    end

    let(:topic_bold) { build_topic_with_title("Topic with <b>bold</b> text in its title") }
    let(:topic_image) { build_topic_with_title("Topic with <img src='something'> image in its title") }
    let(:topic_script) { build_topic_with_title("Topic with <script>alert('title')</script> script in its title") }
    let(:topic_emoji) { build_topic_with_title("I 💖 candy alot") }
    let(:topic_modifier_emoji) { build_topic_with_title("I 👨‍🌾 candy alot") }
    let(:topic_shortcut_emoji) { build_topic_with_title("I love candy :)") }

    it "escapes script contents" do
      expect(topic_script.fancy_title).to eq("Topic with &lt;script&gt;alert(&lsquo;title&rsquo;)&lt;/script&gt; script in its title")
    end

    it "expands emojis" do
      expect(topic_emoji.fancy_title).to eq("I :sparkling_heart: candy alot")
    end

    it "keeps combined emojis" do
      expect(topic_modifier_emoji.fancy_title).to eq("I :man_farmer: candy alot")
    end

    it "escapes bold contents" do
      expect(topic_bold.fancy_title).to eq("Topic with &lt;b&gt;bold&lt;/b&gt; text in its title")
    end

    it "escapes image contents" do
      expect(topic_image.fancy_title).to eq("Topic with &lt;img src=&lsquo;something&rsquo;&gt; image in its title")
    end

    it "always escapes title" do
      topic_script.title = topic_script.title + "x" * Topic.max_fancy_title_length
      expect(topic_script.fancy_title).to eq(ERB::Util.html_escape(topic_script.title))
      # not really needed, but just in case
      expect(topic_script.fancy_title).not_to include("<script>")
    end

    context "emoji shortcuts enabled" do
      before { SiteSetting.enable_emoji_shortcuts = true }

      it "converts emoji shortcuts into emoji" do
        expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :slight_smile:")
      end

      context "emojis disabled" do
        before { SiteSetting.enable_emoji = false }

        it "does not convert emoji shortcuts" do
          expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :)")
        end
      end
    end

    context "emoji shortcuts disabled" do
      before { SiteSetting.enable_emoji_shortcuts = false }

      it "does not convert emoji shortcuts" do
        expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :)")
      end
    end
  end

  context 'fancy title' do
    let(:topic) { Fabricate.build(:topic, title: %{"this topic" -- has ``fancy stuff''}) }

    context 'title_fancy_entities disabled' do
      before do
        SiteSetting.title_fancy_entities = false
      end

      it "doesn't add entities to the title" do
        expect(topic.fancy_title).to eq("&quot;this topic&quot; -- has ``fancy stuff&#39;&#39;")
      end
    end

    context 'title_fancy_entities enabled' do
      before do
        SiteSetting.title_fancy_entities = true
      end

      it "converts the title to have fancy entities and updates" do
        expect(topic.fancy_title).to eq("&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;")
        topic.title = "this is my test hello world... yay"
        topic.save!
        topic.reload
        expect(topic.fancy_title).to eq("This is my test hello world&hellip; yay")

        topic.title = "I made a change to the title"
        topic.save!

        topic.reload
        expect(topic.fancy_title).to eq("I made a change to the title")

        # another edge case
        topic.title = "this is another edge case"
        expect(topic.fancy_title).to eq("this is another edge case")
      end

      it "works with long title that results in lots of entities" do
        long_title = "NEW STOCK PICK: PRCT - LAST PICK UP 233%, NNCO#{"." * 150} ofoum"
        topic.title = long_title

        expect { topic.save! }.to_not raise_error
        expect(topic.fancy_title).to eq(long_title)
      end

      context 'readonly mode' do
        before do
          Discourse.enable_readonly_mode
        end

        after do
          Discourse.disable_readonly_mode
        end

        it 'should not attempt to update `fancy_title`' do
          topic.save!
          expect(topic.fancy_title).to eq('&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;')

          topic.title = "This is a test testing testing"
          expect(topic.fancy_title).to eq("This is a test testing testing")

          expect(topic.reload.read_attribute(:fancy_title))
            .to eq('&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;')
        end
      end
    end
  end

  context 'category validation' do
    fab!(:category) { Fabricate(:category_with_definition) }

    context 'allow_uncategorized_topics is false' do
      before do
        SiteSetting.allow_uncategorized_topics = false
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
        expect(Fabricate.build(:topic, category: category)).to be_valid
      end
    end

    context 'allow_uncategorized_topics is true' do
      before do
        SiteSetting.allow_uncategorized_topics = true
      end

      it "passes for topics with nil category" do
        expect(Fabricate.build(:topic, category: nil)).to be_valid
      end

      it 'passes for topics with a category' do
        expect(Fabricate.build(:topic, category: category)).to be_valid
      end
    end
  end

  context 'similar_to' do

    it 'returns blank with nil params' do
      expect(Topic.similar_to(nil, nil)).to be_blank
    end

    context "with a category definition" do
      let!(:category) { Fabricate(:category_with_definition) }

      it "excludes the category definition topic from similar_to" do
        expect(Topic.similar_to('category definition for', "no body")).to be_blank
      end
    end

    context 'with a similar topic' do
      let!(:topic) {
        SearchIndexer.enable
        post = create_post(title: "Evil trout is the dude who posted this topic")
        post.topic
      }

      it 'returns the similar topic if the title is similar' do
        expect(Topic.similar_to("has evil trout made any topics?", "i am wondering has evil trout made any topics?")).to eq([topic])
      end

      context "secure categories" do
        fab!(:category) { Fabricate(:category_with_definition, read_restricted: true) }

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

  describe '#invite' do
    fab!(:topic) { Fabricate(:topic, user: user) }

    context 'rate limits' do
      before do
        SiteSetting.max_topic_invitations_per_day = 1
        RateLimiter.enable
      end

      after do
        RateLimiter.clear_all!
        RateLimiter.disable
      end

      it "rate limits topic invitations" do
        start = Time.now.tomorrow.beginning_of_day
        freeze_time(start)

        topic = Fabricate(:topic, user: trust_level_2)

        topic.invite(topic.user, user.username)

        expect {
          topic.invite(topic.user, another_user.username)
        }.to raise_error(RateLimiter::LimitExceeded)
      end

      it "rate limits PM invitations" do
        start = Time.now.tomorrow.beginning_of_day
        freeze_time(start)

        topic = Fabricate(:private_message_topic, user: trust_level_2)

        topic.invite(topic.user, user.username)

        expect {
          topic.invite(topic.user, another_user.username)
        }.to raise_error(RateLimiter::LimitExceeded)
      end
    end

    describe 'when username_or_email is not valid' do
      it 'should return the right value' do
        expect do
          expect(topic.invite(user, 'somerandomstring')).to eq(nil)
        end.to_not change { topic.allowed_users }
      end
    end

    describe 'when user is already allowed' do
      it 'should raise the right error' do
        topic.allowed_users << another_user

        expect { topic.invite(user, another_user.username) }
          .to raise_error(Topic::UserExists)
      end
    end

    describe 'private message' do
      fab!(:user) { trust_level_2 }
      fab!(:topic) { Fabricate(:private_message_topic, user: trust_level_2) }

      describe 'by username' do
        it 'should be able to invite a user' do
          expect(topic.invite(user, another_user.username)).to eq(true)
          expect(topic.allowed_users).to include(another_user)
          expect(Post.last.action_code).to eq("invited_user")

          notification = Notification.last

          expect(notification.notification_type)
            .to eq(Notification.types[:invited_to_private_message])

          expect(topic.remove_allowed_user(user, another_user.username)).to eq(true)
          expect(topic.reload.allowed_users).to_not include(another_user)
          expect(Post.last.action_code).to eq("removed_user")
        end

        context "from a muted user" do
          before { MutedUser.create!(user: another_user, muted_user: user) }

          it 'silently fails' do
            expect(topic.invite(user, another_user.username)).to eq(true)
            expect(topic.allowed_users).to_not include(another_user)
            expect(Post.last).to be_blank
            expect(Notification.last).to be_blank
          end
        end

        context "when PMs are enabled for TL3 or higher only" do
          before do
            SiteSetting.min_trust_to_send_messages = 3
          end

          it 'should raise error' do
            expect { topic.invite(user, another_user.username) }
              .to raise_error(Topic::UserExists)
          end
        end
      end

      describe 'by email' do
        it 'should be able to invite a user' do
          expect(topic.invite(user, another_user.email)).to eq(true)
          expect(topic.allowed_users).to include(another_user)

          expect(Notification.last.notification_type)
            .to eq(Notification.types[:invited_to_private_message])
        end

        describe 'when user is not found' do
          it 'should create the right invite' do
            expect(topic.invite(user, 'test@email.com')).to eq(true)

            invite = Invite.last

            expect(invite.email).to eq('test@email.com')
            expect(invite.invited_by).to eq(user)
          end

          describe 'when user does not have sufficient trust level' do
            before { user.update!(trust_level: TrustLevel[1]) }

            it 'should not create an invite' do
              expect do
                expect(topic.invite(user, 'test@email.com')).to eq(nil)
              end.to_not change { Invite.count }
            end
          end
        end
      end
    end

    describe 'public topic' do
      def expect_the_right_notification_to_be_created(inviter, invitee)
        notification = Notification.last

        expect(notification.notification_type)
          .to eq(Notification.types[:invited_to_topic])

        expect(notification.user).to eq(invitee)
        expect(notification.topic).to eq(topic)

        notification_data = JSON.parse(notification.data)

        expect(notification_data["topic_title"]).to eq(topic.title)
        expect(notification_data["display_username"]).to eq(inviter.username)
      end

      describe 'by username' do
        it 'should invite user into a topic' do
          topic.invite(user, another_user.username)
          expect_the_right_notification_to_be_created(user, another_user)
        end
      end

      describe 'by email' do
        it 'should be able to invite a user' do
          expect(topic.invite(user, another_user.email)).to eq(true)
          expect_the_right_notification_to_be_created(user, another_user)
        end

        describe 'when topic belongs to a private category' do
          fab!(:group) { Fabricate(:group) }

          fab!(:category) do
            Fabricate(:category_with_definition, groups: [group]).tap do |category|
              category.set_permissions(group => :full)
              category.save!
            end
          end

          fab!(:topic) { Fabricate(:topic, category: category) }
          let(:inviter) { Fabricate(:user).tap { |user| group.add_owner(user) } }
          fab!(:invitee) { Fabricate(:user) }

          describe 'as a group owner' do
            it 'should be able to invite a user' do
              expect do
                expect(topic.invite(inviter, invitee.email, [group.id]))
                  .to eq(true)
              end.to change { Notification.count } &
                     change { GroupHistory.count }

              expect_the_right_notification_to_be_created(inviter, invitee)

              group_history = GroupHistory.last

              expect(group_history.acting_user).to eq(inviter)
              expect(group_history.target_user).to eq(invitee)

              expect(group_history.action).to eq(
                GroupHistory.actions[:add_user_to_group]
              )
            end

            describe 'when group ids are not given' do
              it 'should not invite the user' do
                expect do
                  expect(topic.invite(inviter, invitee.email)).to eq(false)
                end.to_not change { Notification.count }
              end
            end
          end

          describe 'as a normal user' do
            it 'should not be able to invite a user' do
              expect do
                expect(topic.invite(Fabricate(:user), invitee.email, [group.id]))
                  .to eq(false)
              end.to_not change { Notification.count }
            end
          end
        end

        context "for a muted topic" do
          before { TopicUser.change(another_user.id, topic.id, notification_level: TopicUser.notification_levels[:muted]) }

          it 'silently fails' do
            expect(topic.invite(user, another_user.username)).to eq(true)
            expect(topic.allowed_users).to_not include(another_user)
            expect(Post.last).to be_blank
            expect(Notification.last).to be_blank
          end
        end

        describe 'when user can invite via email' do
          before { user.update!(trust_level: TrustLevel[2]) }

          it 'should create an invite' do
            expect(topic.invite(user, 'test@email.com')).to eq(true)

            invite = Invite.last

            expect(invite.email).to eq('test@email.com')
            expect(invite.invited_by).to eq(user)
          end
        end
      end
    end
  end

  context 'private message' do
    let(:coding_horror) { User.find_by(username: "CodingHorror") }
    fab!(:evil_trout) { Fabricate(:evil_trout) }
    let(:topic) { Fabricate(:private_message_topic) }

    it "should integrate correctly" do
      expect(Guardian.new(topic.user).can_see?(topic)).to eq(true)
      expect(Guardian.new.can_see?(topic)).to eq(false)
      expect(Guardian.new(evil_trout).can_see?(topic)).to eq(false)
      expect(Guardian.new(coding_horror).can_see?(topic)).to eq(true)
      expect(TopicQuery.new(evil_trout).list_latest.topics).not_to include(topic)
    end

    context 'invite' do

      context 'existing user' do

        context 'by group name' do
          fab!(:group) { Fabricate(:group) }

          it 'can add admin to allowed groups' do
            admins = Group[:admins]
            admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])

            expect(topic.invite_group(topic.user, admins)).to eq(true)
            expect(topic.allowed_groups.include?(admins)).to eq(true)
            expect(topic.remove_allowed_group(topic.user, 'admins')).to eq(true)
            expect(topic.allowed_groups.include?(admins)).to eq(false)
          end

          def set_state!(group, user, state)
            group.group_users.find_by(user_id: user.id).update!(
              notification_level: NotificationLevels.all[state]
            )
          end

          it 'creates a notification for each user in the group' do

            # trigger notification
            user_watching_first = Fabricate(:user)
            user_watching = Fabricate(:user)

            # trigger rollup
            user_tracking = Fabricate(:user)

            # trigger nothing
            user_normal = Fabricate(:user)
            user_muted = Fabricate(:user)

            Fabricate(:post, topic: topic)

            group.add(topic.user) # no notification even though watching
            group.add(user_watching_first)
            group.add(user_watching)
            group.add(user_normal)
            group.add(user_muted)
            group.add(user_tracking)

            set_state!(group, topic.user, :watching)
            set_state!(group, user_watching, :watching)
            set_state!(group, user_watching_first, :watching_first_post)
            set_state!(group, user_tracking, :tracking)
            set_state!(group, user_normal, :regular)
            set_state!(group, user_muted, :muted)

            Notification.delete_all
            topic.invite_group(topic.user, group)

            expect(Notification.count).to eq(3)

            [user_watching, user_watching_first].each do |u|
              notifications = Notification.where(user_id: u.id).to_a
              expect(notifications.length).to eq(1)

              notification = notifications.first

              expect(notification.topic).to eq(topic)
              expect(notification.notification_type)
                .to eq(Notification.types[:invited_to_private_message])

            end

            notifications = Notification.where(user_id: user_tracking.id).to_a
            expect(notifications.length).to eq(1)
            notification = notifications.first

            expect(notification.notification_type)
              .to eq(Notification.types[:group_message_summary])

          end
        end
      end
    end

    context "user actions" do
      it "should set up actions correctly" do
        UserActionManager.enable

        post = create_post(archetype: 'private_message', target_usernames: [user.username])
        actions = post.user.user_actions

        expect(actions.map { |a| a.action_type }).not_to include(UserAction::NEW_TOPIC)
        expect(actions.map { |a| a.action_type }).to include(UserAction::NEW_PRIVATE_MESSAGE)
        expect(user.user_actions.map { |a| a.action_type }).to include(UserAction::GOT_PRIVATE_MESSAGE)
      end

    end

  end

  context 'bumping topics' do
    let!(:topic) { Fabricate(:topic, bumped_at: 1.year.ago) }

    it 'updates the bumped_at field when a new post is made' do
      expect(topic.bumped_at).to be_present
      expect {
        create_post(topic: topic, user: topic.user)
        topic.reload
      }.to change(topic, :bumped_at)
    end

    context 'editing posts' do
      before do
        @earlier_post = Fabricate(:post, topic: topic, user: topic.user)
        @last_post = Fabricate(:post, topic: topic, user: topic.user)
        topic.reload
      end

      it "doesn't bump the topic on an edit to the last post that doesn't result in a new version" do
        expect {
          SiteSetting.editing_grace_period = 5.minutes
          @last_post.revise(@last_post.user, { raw: @last_post.raw + "a" }, revised_at: @last_post.created_at + 10.seconds)
          topic.reload
        }.not_to change(topic, :bumped_at)
      end

      it "bumps the topic when a new version is made of the last post" do
        expect {
          @last_post.revise(Fabricate(:moderator), raw: 'updated contents')
          topic.reload
        }.to change(topic, :bumped_at)
      end

      it "doesn't bump the topic when a post that isn't the last post receives a new version" do
        expect {
          @earlier_post.revise(Fabricate(:moderator), raw: 'updated contents')
          topic.reload
        }.not_to change(topic, :bumped_at)
      end

      it "doesn't bump the topic when a post have invalid topic title while edit" do
        expect {
          @last_post.revise(Fabricate(:moderator), title: 'invalid title')
          topic.reload
        }.not_to change(topic, :bumped_at)
      end
    end
  end

  context 'moderator posts' do
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:topic) { Fabricate(:topic) }

    it 'creates a moderator post' do
      mod_post = topic.add_moderator_post(
        moderator,
        "Moderator did something. http://discourse.org",
        post_number: 999
      )

      expect(mod_post).to be_present
      expect(mod_post.post_type).to eq(Post.types[:moderator_action])
      expect(mod_post.post_number).to eq(999)
      expect(mod_post.sort_order).to eq(999)
      expect(topic.topic_links.count).to eq(1)
      expect(topic.reload.moderator_posts_count).to eq(1)
    end

    context "when moderator post fails to be created" do
      before do
        user.update_column(:silenced_till, 1.year.from_now)
      end

      it "should not increment moderator_posts_count" do
        expect(topic.moderator_posts_count).to eq(0)

        topic.add_moderator_post(user, "winter is never coming")

        expect(topic.moderator_posts_count).to eq(0)
      end
    end
  end

  context 'update_status' do
    fab!(:topic) { Fabricate(:topic, bumped_at: 1.hour.ago) }

    before do
      @original_bumped_at = topic.bumped_at.to_f
      @user = topic.user
      @user.admin = true
    end

    context 'visibility' do
      context 'disable' do
        before do
          topic.update_status('visible', false, @user)
          topic.reload
        end

        it 'should not be visible and have correct counts' do
          expect(topic).not_to be_visible
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
        end
      end

      context 'enable' do
        before do
          topic.update_attribute :visible, false
          topic.update_status('visible', true, @user)
          topic.reload
        end

        it 'should be visible with correct counts' do
          expect(topic).to be_visible
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
        end
      end
    end

    context 'pinned' do
      context 'disable' do
        before do
          topic.update_status('pinned', false, @user)
          topic.reload
        end

        it "doesn't have a pinned_at but has correct dates" do
          expect(topic.pinned_at).to be_blank
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
        end
      end

      context 'enable' do
        before do
          topic.update_attribute :pinned_at, nil
          topic.update_status('pinned', true, @user)
          topic.reload
        end

        it 'should enable correctly' do
          expect(topic.pinned_at).to be_present
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
          expect(topic.moderator_posts_count).to eq(1)
        end

      end
    end

    context 'archived' do
      context 'disable' do
        before do
          @archived_topic = Fabricate(:topic, archived: true, bumped_at: 1.hour.ago)
          @original_bumped_at = @archived_topic.bumped_at.to_f
          @archived_topic.update_status('archived', false, @user)
          @archived_topic.reload
        end

        it 'should archive correctly' do
          expect(@archived_topic).not_to be_archived
          expect(@archived_topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
          expect(@archived_topic.moderator_posts_count).to eq(1)
        end
      end

      context 'enable' do
        before do
          topic.update_attribute :archived, false
          topic.update_status('archived', true, @user)
          topic.reload
        end

        it 'should be archived' do
          expect(topic).to be_archived
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
        end
      end
    end

    shared_examples_for 'a status that closes a topic' do
      context 'disable' do
        before do
          @closed_topic = Fabricate(:topic, closed: true, bumped_at: 1.hour.ago)
          @original_bumped_at = @closed_topic.bumped_at.to_f
          @closed_topic.update_status(status, false, @user)
          @closed_topic.reload
        end

        it 'should not be pinned' do
          expect(@closed_topic).not_to be_closed
          expect(@closed_topic.moderator_posts_count).to eq(1)
          expect(@closed_topic.bumped_at.to_f).not_to be_within(1e-4).of(@original_bumped_at)
        end
      end

      context 'enable' do
        before do
          topic.update_attribute :closed, false
          topic.update_status(status, true, @user)
          topic.reload
        end

        it 'should be closed' do
          expect(topic).to be_closed
          expect(topic.bumped_at.to_f).to be_within(1e-4).of(@original_bumped_at)
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.topic_timers.first).to eq(nil)
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
        it 'includes the autoclose duration in the moderator post' do
          freeze_time(Time.new(2000, 1, 1))
          topic.created_at = 3.days.ago
          topic.update_status(status, true, @user)
          expect(topic.posts.last.raw).to include "closed after 3 days"
        end
      end

      context 'topic was set to close after it was created' do
        it 'includes the autoclose duration in the moderator post' do
          freeze_time(Time.new(2000, 1, 1))

          topic.created_at = 7.days.ago

          freeze_time(2.days.ago)

          topic.set_or_create_timer(TopicTimer.types[:close], 48)
          topic.save!

          freeze_time(2.days.from_now)

          topic.update_status(status, true, @user)
          expect(topic.posts.last.raw).to include "closed after 2 days"
        end
      end
    end
  end

  describe "banner" do

    fab!(:topic) { Fabricate(:topic) }
    fab!(:user) { topic.user }
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

      it "removes any dismissed banner keys" do
        user.user_profile.update_column(:dismissed_banner_key, topic.id)

        topic.make_banner!(user)
        user.user_profile.reload
        expect(user.user_profile.dismissed_banner_key).to be_nil
      end

    end

    describe "remove_banner!" do

      it "resets the topic archetype" do
        topic.expects(:add_moderator_post)

        message = MessageBus.track_publish do
          topic.remove_banner!(user)
        end.first

        expect(topic.archetype).to eq(Archetype.default)
        expect(message.channel).to eq("/site/banner")
        expect(message.data).to eq(nil)
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
      @category = Fabricate(:category_with_definition)
    end

    it "should not increase the topic_count with no category" do
      expect { Fabricate(:topic, user: @category.user); @category.reload }.not_to change(@category, :topic_count)
    end

    it "should increase the category's topic_count" do
      expect { Fabricate(:topic, user: @category.user, category_id: @category.id); @category.reload }.to change(@category, :topic_count).by(1)
    end
  end

  describe 'meta data' do
    fab!(:topic) { Fabricate(:topic, meta_data: { 'hello' => 'world' }) }

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

    fab!(:topic) { Fabricate(:topic) }

    it 'is a regular topic by default' do
      expect(topic.archetype).to eq(Archetype.default)
      expect(topic.has_summary).to eq(false)
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

  describe '#change_category_to_id' do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:user) { topic.user }
    fab!(:category) { Fabricate(:category_with_definition, user: user) }

    describe 'without a previous category' do
      it 'changes the category' do
        topic.change_category_to_id(category.id)
        category.reload
        expect(topic.category).to eq(category)
        expect(category.topic_count).to eq(1)
      end

      it 'should not change the topic_count when not changed' do
        expect { topic.change_category_to_id(topic.category.id); category.reload }.not_to change(category, :topic_count)
      end

      it "doesn't change the category when it can't be found" do
        topic.change_category_to_id(12312312)
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      it "changes the category even when the topic title is invalid" do
        SiteSetting.min_topic_title_length = 5
        topic.update_column(:title, "xyz")
        expect { topic.change_category_to_id(category.id) }.to change { topic.category_id }.to(category.id)
      end
    end

    describe 'with a previous category' do
      before do
        topic.change_category_to_id(category.id)
        topic.reload
        category.reload
      end

      it "doesn't change the topic_count when the value doesn't change" do
        expect(category.topic_count).to eq(1)
        expect { topic.change_category_to_id(category.id); category.reload }.not_to change(category, :topic_count)
      end

      it "doesn't reset the category when an id that doesn't exist" do
        topic.change_category_to_id(55556)
        expect(topic.category_id).to eq(category.id)
      end

      describe 'to a different category' do
        fab!(:new_category) { Fabricate(:category_with_definition, user: user, name: '2nd category') }

        it 'should work' do
          topic.change_category_to_id(new_category.id)

          expect(topic.reload.category).to eq(new_category)
          expect(new_category.reload.topic_count).to eq(1)
          expect(category.reload.topic_count).to eq(0)
        end

        describe 'user that is watching the new category' do

          before do
            Jobs.run_immediately!

            topic.posts << Fabricate(:post)

            CategoryUser.set_notification_level_for_category(
              user,
              CategoryUser::notification_levels[:watching],
              new_category.id
            )

            CategoryUser.set_notification_level_for_category(
              another_user,
              CategoryUser::notification_levels[:watching_first_post],
              new_category.id
            )
          end

          it 'should generate the notification for the topic' do
            expect do
              topic.change_category_to_id(new_category.id)
            end.to change { Notification.count }.by(2)

            expect(Notification.where(
              user_id: user.id,
              topic_id: topic.id,
              post_number: 1,
              notification_type: Notification.types[:posted]
            ).exists?).to eq(true)

            expect(Notification.where(
              user_id: another_user.id,
              topic_id: topic.id,
              post_number: 1,
              notification_type: Notification.types[:watching_first_post]
            ).exists?).to eq(true)
          end

          it "should not generate a notification for unlisted topic" do
            topic.update_column(:visible, false)

            expect do
              topic.change_category_to_id(new_category.id)
            end.to change { Notification.count }.by(0)
          end
        end

        describe 'when new category is set to auto close by default' do
          before do
            new_category.update!(auto_close_hours: 5)
          end

          it 'should set a topic timer' do
            expect { topic.change_category_to_id(new_category.id) }
              .to change { TopicTimer.count }.by(1)

            expect(topic.reload.category).to eq(new_category)

            topic_timer = TopicTimer.last

            expect(topic_timer.topic).to eq(topic)
            expect(topic_timer.execute_at).to be_within(1.second).of(Time.zone.now + 5.hours)
          end

          describe 'when topic is already closed' do
            before do
              topic.update_status('closed', true, Discourse.system_user)
            end

            it 'should not set a topic timer' do
              expect { topic.change_category_to_id(new_category.id) }
                .to change { TopicTimer.with_deleted.count }.by(0)

              expect(topic.closed).to eq(true)
              expect(topic.reload.category).to eq(new_category)
            end
          end

          describe 'when topic has an existing topic timer' do
            let(:topic_timer) { Fabricate(:topic_timer, topic: topic) }

            it "should not inherit category's auto close hours" do
              topic_timer
              topic.change_category_to_id(new_category.id)

              expect(topic.reload.category).to eq(new_category)

              expect(topic.public_topic_timer).to eq(topic_timer)

              expect(topic.public_topic_timer.execute_at)
                .to be_within(1.second).of(topic_timer.execute_at)
            end
          end
        end
      end

      context 'when allow_uncategorized_topics is false' do
        before do
          SiteSetting.allow_uncategorized_topics = false
        end

        let!(:topic) { Fabricate(:topic, category: Fabricate(:category_with_definition)) }

        it 'returns false' do
          expect(topic.change_category_to_id(nil)).to eq(false) # don't use "== false" here because it would also match nil
        end
      end

      describe 'when the category exists' do
        before do
          topic.change_category_to_id(nil)
          category.reload
        end

        it "resets the category" do
          expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
          expect(category.topic_count).to eq(0)
        end
      end

    end

  end

  describe 'scopes' do
    describe '#by_most_recently_created' do
      it 'returns topics ordered by created_at desc, id desc' do
        now = Time.now
        a = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        b = Fabricate(:topic, user: user, created_at: now)
        c = Fabricate(:topic, user: user, created_at: now)
        d = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        expect(Topic.by_newest).to eq([c, b, d, a])
      end
    end

    describe '#created_since' do
      it 'returns topics created after some date' do
        now = Time.now
        a = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        b = Fabricate(:topic, user: user, created_at: now - 1.minute)
        c = Fabricate(:topic, user: user, created_at: now)
        d = Fabricate(:topic, user: user, created_at: now + 1.minute)
        e = Fabricate(:topic, user: user, created_at: now + 2.minutes)
        expect(Topic.created_since(now)).not_to include a
        expect(Topic.created_since(now)).not_to include b
        expect(Topic.created_since(now)).not_to include c
        expect(Topic.created_since(now)).to include d
        expect(Topic.created_since(now)).to include e
      end
    end

    describe '#visible' do
      it 'returns topics set as visible' do
        a = Fabricate(:topic, user: user, visible: false)
        b = Fabricate(:topic, user: user, visible: true)
        c = Fabricate(:topic, user: user, visible: true)
        expect(Topic.visible).not_to include a
        expect(Topic.visible).to include b
        expect(Topic.visible).to include c
      end
    end

    describe '#in_category_and_subcategories' do
      it 'returns topics in a category and its subcategories' do
        c1 = Fabricate(:category_with_definition)
        c2 = Fabricate(:category_with_definition, parent_category_id: c1.id)
        c3 = Fabricate(:category_with_definition)

        t1 = Fabricate(:topic, user: user, category_id: c1.id)
        t2 = Fabricate(:topic, user: user, category_id: c2.id)
        t3 = Fabricate(:topic, user: user, category_id: c3.id)

        expect(Topic.in_category_and_subcategories(c1.id)).not_to include(t3)
        expect(Topic.in_category_and_subcategories(c1.id)).to include(t2)
        expect(Topic.in_category_and_subcategories(c1.id)).to include(t1)
      end
    end
  end

  describe '#private_topic_timer' do
    let(:topic_timer) do
      Fabricate(:topic_timer,
        public_type: false,
        user: user,
        status_type: TopicTimer.private_types[:reminder]
      )
    end

    it 'should return the right record' do
      expect(topic_timer.topic.private_topic_timer(user)).to eq(topic_timer)
    end
  end

  describe '#set_or_create_timer' do
    let(:topic) { Fabricate.build(:topic) }

    let(:closing_topic) do
      Fabricate(:topic_timer, execute_at: 5.hours.from_now).topic
    end

    fab!(:admin) { Fabricate(:admin) }
    fab!(:trust_level_4) { Fabricate(:trust_level_4) }

    it 'can take a number of hours as an integer' do
      freeze_time now

      topic.set_or_create_timer(TopicTimer.types[:close], 72, by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq(3.days.from_now)
    end

    it 'can take a number of hours as a string' do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], '18', by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq(18.hours.from_now)
    end

    it 'can take a number of hours as a string and can handle based on last post' do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], '18', by_user: admin, based_on_last_post: true)
      expect(topic.topic_timers.first.execute_at).to eq(18.hours.from_now)
    end

    it "can take a timestamp for a future time" do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], '2013-11-22 5:00', by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq(Time.zone.local(2013, 11, 22, 5, 0))
    end

    it "sets a validation error when given a timestamp in the past" do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], '2013-11-19 5:00', by_user: admin)

      expect(topic.topic_timers.first.execute_at).to eq(Time.zone.local(2013, 11, 19, 5, 0))
      expect(topic.topic_timers.first.errors[:execute_at]).to be_present
    end

    it "sets a validation error when give a timestamp of an invalid format" do
      freeze_time now

      expect do
        topic.set_or_create_timer(
          TopicTimer.types[:close],
          '۲۰۱۸-۰۳-۲۶ ۱۸:۰۰+۰۸:۰۰',
          by_user: admin
        )
      end.to raise_error(Discourse::InvalidParameters)
    end

    it "can take a timestamp with timezone" do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], '2013-11-25T01:35:00-08:00', by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq(Time.utc(2013, 11, 25, 9, 35))
    end

    it 'sets topic status update user to given user if it is a staff or TL4 user' do
      topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: admin)
      expect(topic.topic_timers.first.user).to eq(admin)
    end

    it 'sets topic status update user to given user if it is a TL4 user' do
      topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: trust_level_4)
      expect(topic.topic_timers.first.user).to eq(trust_level_4)
    end

    it 'sets topic status update user to system user if given user is not staff or a TL4 user' do
      topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: Fabricate.build(:user, id: 444))
      expect(topic.topic_timers.first.user).to eq(Discourse.system_user)
    end

    it 'sets topic status update user to system user if user is not given and topic creator is not staff nor TL4 user' do
      topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(topic.topic_timers.first.user).to eq(Discourse.system_user)
    end

    it 'sets topic status update user to topic creator if it is a staff user' do
      staff_topic = Fabricate.build(:topic, user: Fabricate.build(:admin, id: 999))
      staff_topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(staff_topic.topic_timers.first.user_id).to eq(999)
    end

    it 'sets topic status update user to topic creator if it is a TL4 user' do
      tl4_topic = Fabricate.build(:topic, user: Fabricate.build(:trust_level_4, id: 998))
      tl4_topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(tl4_topic.topic_timers.first.user_id).to eq(998)
    end

    it 'removes close topic status update if arg is nil' do
      closing_topic.set_or_create_timer(TopicTimer.types[:close], nil)
      closing_topic.reload
      expect(closing_topic.topic_timers.first).to be_nil
    end

    it 'updates topic status update execute_at if it was already set to close' do
      freeze_time now
      closing_topic.set_or_create_timer(TopicTimer.types[:close], 48)
      expect(closing_topic.reload.public_topic_timer.execute_at).to eq(2.days.from_now)
    end

    it 'should not delete topic_timer of another status_type' do
      freeze_time
      closing_topic.set_or_create_timer(TopicTimer.types[:open], nil)
      topic_timer = closing_topic.public_topic_timer

      expect(topic_timer.execute_at).to eq_time(5.hours.from_now)
      expect(topic_timer.status_type).to eq(TopicTimer.types[:close])
    end

    it 'should allow status_type to be updated' do
      freeze_time

      topic_timer = closing_topic.set_or_create_timer(
        TopicTimer.types[:publish_to_category], 72, by_user: admin
      )

      expect(topic_timer.execute_at).to eq(3.days.from_now)
    end

    it "does not update topic's topic status created_at it was already set to close" do
      expect {
        closing_topic.set_or_create_timer(TopicTimer.types[:close], 14)
      }.to_not change { closing_topic.topic_timers.first.created_at }
    end

    describe "when category's default auto close is set" do
      let(:category) { Fabricate(:category_with_definition, auto_close_hours: 4) }
      let(:topic) { Fabricate(:topic, category: category) }

      it "should be able to override category's default auto close" do
        Jobs.run_immediately!

        expect(topic.topic_timers.first.duration).to eq(4)

        topic.set_or_create_timer(TopicTimer.types[:close], 2, by_user: admin)

        expect(topic.reload.closed).to eq(false)

        freeze_time 3.hours.from_now

        TopicTimer.ensure_consistency!
        expect(topic.reload.closed).to eq(true)
      end
    end

    describe "private status type" do
      fab!(:topic) { Fabricate(:topic) }
      let(:reminder) { Fabricate(:topic_timer, user: admin, topic: topic, status_type: TopicTimer.types[:reminder]) }
      fab!(:other_admin) { Fabricate(:admin) }

      it "lets two users have their own record" do
        reminder
        expect {
          topic.set_or_create_timer(TopicTimer.types[:reminder], 2, by_user: other_admin)
        }.to change { TopicTimer.count }.by(1)
      end

      it 'should not be override when setting a public topic timer' do
        reminder

        expect do
          topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: reminder.user)
        end.to change { TopicTimer.count }.by(1)
      end

      it "can update a user's existing record" do
        freeze_time now

        reminder
        expect {
          topic.set_or_create_timer(TopicTimer.types[:reminder], 11, by_user: admin)
        }.to_not change { TopicTimer.count }
        reminder.reload
        expect(reminder.execute_at).to eq(11.hours.from_now)
      end
    end
  end

  describe '.for_digest' do
    let(:user) { Fabricate.build(:user) }

    context "no edit grace period" do
      before do
        SiteSetting.editing_grace_period = 0
      end

      it "returns none when there are no topics" do
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return category topics" do
        Fabricate(:category_with_definition)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns regular topics" do
        topic = Fabricate(:topic)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "doesn't return topics from muted categories" do
        user = Fabricate(:user)
        category = Fabricate(:category_with_definition)
        Fabricate(:topic, category: category)

        CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[:muted], category.id)

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return topics that a user has muted" do
        topic = Fabricate(:topic)
        user = Fabricate(:user)

        Fabricate(:topic_user,
          user: user,
          topic: topic,
          notification_level: TopicUser.notification_levels[:muted]
        )

        expect(Topic.for_digest(user, 1.year.ago)).to eq([])
      end

      it "doesn't return topics from suppressed categories" do
        user = Fabricate(:user)
        category = Fabricate(:category_with_definition)
        Fabricate(:topic, category: category)

        SiteSetting.digest_suppress_categories = "#{category.id}"

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return topics from TL0 users" do
        new_user = Fabricate(:user, trust_level: 0)
        Fabricate(:topic, user: new_user)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns topics from TL0 users if given include_tl0" do
        new_user = Fabricate(:user, trust_level: 0)
        topic = Fabricate(:topic, user_id: new_user.id)

        expect(Topic.for_digest(user, 1.year.ago, top_order: true, include_tl0: true)).to eq([topic])
      end

      it "returns topics from TL0 users if enabled in preferences" do
        new_user = Fabricate(:user, trust_level: 0)
        topic = Fabricate(:topic, user: new_user)

        u = Fabricate(:user)
        u.user_option.include_tl0_in_digests = true

        expect(Topic.for_digest(u, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "doesn't return topics with only muted tags" do
        user = Fabricate(:user)
        tag = Fabricate(:tag)
        TagUser.change(user.id, tag.id, TagUser.notification_levels[:muted])
        Fabricate(:topic, tags: [tag])

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns topics with both muted and not muted tags" do
        user = Fabricate(:user)
        muted_tag, other_tag = Fabricate(:tag), Fabricate(:tag)
        TagUser.change(user.id, muted_tag.id, TagUser.notification_levels[:muted])
        topic = Fabricate(:topic, tags: [muted_tag, other_tag])

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "returns topics with no tags too" do
        user = Fabricate(:user)
        muted_tag = Fabricate(:tag)
        TagUser.change(user.id, muted_tag.id, TagUser.notification_levels[:muted])
        _topic1 = Fabricate(:topic, tags: [muted_tag])
        topic2 = Fabricate(:topic, tags: [Fabricate(:tag), Fabricate(:tag)])
        topic3 = Fabricate(:topic)

        topics = Topic.for_digest(user, 1.year.ago, top_order: true)
        expect(topics.size).to eq(2)
        expect(topics).to contain_exactly(topic2, topic3)
      end

      it "sorts by category notification levels" do
        category1, category2 = Fabricate(:category_with_definition), Fabricate(:category_with_definition)
        2.times { |i| Fabricate(:topic, category: category1) }
        topic1 = Fabricate(:topic, category: category2)
        2.times { |i| Fabricate(:topic, category: category1) }
        CategoryUser.create(user: user, category: category2, notification_level: CategoryUser.notification_levels[:watching])
        for_digest = Topic.for_digest(user, 1.year.ago, top_order: true)
        expect(for_digest.first).to eq(topic1)
      end

      it "sorts by topic notification levels" do
        topics = []
        3.times { |i| topics << Fabricate(:topic) }
        user = Fabricate(:user)
        TopicUser.create(user_id: user.id, topic_id: topics[0].id, notification_level: TopicUser.notification_levels[:tracking])
        TopicUser.create(user_id: user.id, topic_id: topics[2].id, notification_level: TopicUser.notification_levels[:watching])
        for_digest = Topic.for_digest(user, 1.year.ago, top_order: true).pluck(:id)
        expect(for_digest).to eq([topics[2].id, topics[0].id, topics[1].id])
      end
    end

    context "with editing_grace_period" do
      before do
        SiteSetting.editing_grace_period = 5.minutes
      end

      it "excludes topics that are within the grace period" do
        topic1 = Fabricate(:topic, created_at: 6.minutes.ago)
        _topic2 = Fabricate(:topic, created_at: 4.minutes.ago)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic1])
      end
    end
  end

  describe '.secured' do
    it 'should return the right topics' do
      category = Fabricate(:category_with_definition, read_restricted: true)
      topic = Fabricate(:topic, category: category, created_at: 1.day.ago)
      group = Fabricate(:group)
      user = Fabricate(:user)
      group.add(user)
      private_category = Fabricate(:private_category_with_definition, group: group)

      expect(Topic.secured(Guardian.new(nil))).to eq([])

      expect(Topic.secured(Guardian.new(user)))
        .to contain_exactly(private_category.topic)

      expect(Topic.secured(Guardian.new(Fabricate(:admin))))
        .to contain_exactly(category.topic, private_category.topic, topic)
    end
  end

  describe 'all_allowed_users' do
    fab!(:group) { Fabricate(:group) }
    fab!(:topic) { Fabricate(:topic, allowed_groups: [group]) }
    fab!(:allowed_user) { Fabricate(:user) }
    fab!(:allowed_group_user) { Fabricate(:user) }
    fab!(:moderator) { Fabricate(:user, moderator: true) }
    fab!(:rando) { Fabricate(:user) }

    before do
      topic.allowed_users << allowed_user
      group.users << allowed_group_user
    end

    it 'includes allowed_users' do
      expect(topic.all_allowed_users).to include allowed_user
    end

    it 'includes allowed_group_users' do
      expect(topic.all_allowed_users).to include allowed_group_user
    end

    it 'includes moderators if flagged and a pm' do
      topic.stubs(:has_flags?).returns(true)
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).to include moderator
    end

    it 'includes moderators if offical warning' do
      topic.stubs(:subtype).returns(TopicSubtype.moderator_warning)
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).to include moderator
    end

    it 'does not include moderators if pm without flags' do
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).not_to include moderator
    end

    it 'does not include moderators for regular topic' do
      expect(topic.all_allowed_users).not_to include moderator
    end

    it 'does not include randos' do
      expect(topic.all_allowed_users).not_to include rando
    end
  end

  describe '#listable_count_per_day' do
    before(:each) do
      freeze_time DateTime.parse('2017-03-01 12:00')

      Fabricate(:topic)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 2.days.ago)
      Fabricate(:topic, created_at: 4.days.ago)
    end

    let(:listable_topics_count_per_day) { { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1 } }

    it 'collect closed interval listable topics count' do
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).to include(listable_topics_count_per_day)
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).not_to include(4.days.ago.to_date => 1)
    end
  end

  describe '#secure_category?' do
    let(:category) { Category.new }

    it "is true if the category is secure" do
      category.stubs(:read_restricted).returns(true)
      expect(Topic.new(category: category)).to be_read_restricted_category
    end

    it "is false if the category is not secure" do
      category.stubs(:read_restricted).returns(false)
      expect(Topic.new(category: category)).not_to be_read_restricted_category
    end

    it "is false if there is no category" do
      expect(Topic.new(category: nil)).not_to be_read_restricted_category
    end
  end

  describe 'trash!' do
    context "its category's topic count" do
      fab!(:moderator) { Fabricate(:moderator) }
      fab!(:category) { Fabricate(:category_with_definition) }

      it "subtracts 1 if topic is being deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.trash!(moderator) }.to change { category.reload.topic_count }.by(-1)
      end

      it "doesn't subtract 1 if topic is already deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.trash!(moderator) }.to_not change { category.reload.topic_count }
      end
    end

    it "trashes topic embed record" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, post_number: 1)
      topic_embed = TopicEmbed.create!(topic_id: topic.id, embed_url: "https://blog.codinghorror.com/password-rules-are-bullshit", post_id: post.id)
      topic.trash!
      topic_embed.reload
      expect(topic_embed.deleted_at).not_to eq(nil)
    end
  end

  describe 'recover!' do
    context "its category's topic count" do
      fab!(:category) { Fabricate(:category_with_definition) }

      it "adds 1 if topic is deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.recover! }.to change { category.reload.topic_count }.by(1)
      end

      it "doesn't add 1 if topic is not deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.recover! }.to_not change { category.reload.topic_count }
      end
    end

    it "recovers topic embed record" do
      topic = Fabricate(:topic, deleted_at: 1.day.ago)
      post = Fabricate(:post, topic: topic, post_number: 1)
      topic_embed = TopicEmbed.create!(topic_id: topic.id, embed_url: "https://blog.codinghorror.com/password-rules-are-bullshit", post_id: post.id, deleted_at: 1.day.ago)
      topic.recover!
      topic_embed.reload
      expect(topic_embed.deleted_at).to eq(nil)
    end
  end

  context "new user limits" do
    before do
      SiteSetting.max_topics_in_first_day = 1
      SiteSetting.max_replies_in_first_day = 1
      SiteSetting.stubs(:client_settings_json).returns(SiteSetting.client_settings_json_uncached)
      RateLimiter.stubs(:rate_limit_create_topic).returns(100)
      RateLimiter.enable
      RateLimiter.clear_all!
    end

    it "limits new users to max_topics_in_first_day and max_posts_in_first_day" do
      start = Time.now.tomorrow.beginning_of_day

      freeze_time(start)

      user = Fabricate(:user)
      topic_id = create_post(user: user).topic_id

      freeze_time(start + 10.minutes)
      expect { create_post(user: user) }.to raise_error(RateLimiter::LimitExceeded)

      freeze_time(start + 20.minutes)
      create_post(user: user, topic_id: topic_id)

      freeze_time(start + 30.minutes)
      expect { create_post(user: user, topic_id: topic_id) }.to raise_error(RateLimiter::LimitExceeded)
    end

    it "starts counting when they make their first post/topic" do
      start = Time.now.tomorrow.beginning_of_day

      freeze_time(start)

      user = Fabricate(:user)

      freeze_time(start + 25.hours)
      topic_id = create_post(user: user).topic_id

      freeze_time(start + 26.hours)
      expect { create_post(user: user) }.to raise_error(RateLimiter::LimitExceeded)

      freeze_time(start + 27.hours)
      create_post(user: user, topic_id: topic_id)

      freeze_time(start + 28.hours)
      expect { create_post(user: user, topic_id: topic_id) }.to raise_error(RateLimiter::LimitExceeded)
    end
  end

  describe ".count_exceeds_minimun?" do
    before { SiteSetting.minimum_topics_similar = 20 }

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
    expect(topic.custom_fields).to eq("bob" => "marley", "jack" => "black")
  end

  it "doesn't validate the title again if it isn't changing" do
    SiteSetting.min_topic_title_length = 5
    topic = Fabricate(:topic, title: "Short")
    expect(topic).to be_valid

    SiteSetting.min_topic_title_length = 15
    topic.last_posted_at = 1.minute.ago
    expect(topic.save).to eq(true)
  end

  it "Correctly sets #message_archived?" do
    topic = Fabricate(:private_message_topic)
    user = topic.user

    expect(topic.message_archived?(user)).to eq(false)

    group = Fabricate(:group)
    group2 = Fabricate(:group)

    group.add(user)

    TopicAllowedGroup.create!(topic_id: topic.id, group_id: group.id)
    TopicAllowedGroup.create!(topic_id: topic.id, group_id: group2.id)
    GroupArchivedMessage.create!(topic_id: topic.id, group_id: group.id)

    expect(topic.message_archived?(user)).to eq(true)

    # here is a pickle, we add another group, make the user a
    # member of that new group... now this message is not properly archived
    # for the user any more
    group2.add(user)
    expect(topic.message_archived?(user)).to eq(false)
  end

  it 'will trigger :topic_status_updated' do
    topic = Fabricate(:topic)
    user = topic.user
    user.admin = true
    @topic_status_event_triggered = false

    DiscourseEvent.on(:topic_status_updated) do
      @topic_status_event_triggered = true
    end

    topic.update_status('closed', true, user)
    topic.reload

    expect(@topic_status_event_triggered).to eq(true)
  end

  it 'allows users to normalize counts' do

    topic = Fabricate(:topic, last_posted_at: 1.year.ago)
    post1 = Fabricate(:post, topic: topic, post_number: 1)
    post2 = Fabricate(:post, topic: topic, post_type: Post.types[:whisper], post_number: 2)

    Topic.reset_all_highest!
    topic.reload

    expect(topic.posts_count).to eq(1)
    expect(topic.highest_post_number).to eq(post1.post_number)
    expect(topic.highest_staff_post_number).to eq(post2.post_number)
    expect(topic.last_posted_at).to be_within(1.second).of (post1.created_at)
  end

  context 'featured link' do
    before { SiteSetting.topic_featured_link_enabled = true }
    fab!(:topic) { Fabricate(:topic) }

    it 'can validate featured link' do
      topic.featured_link = ' invalid string'

      expect(topic).not_to be_valid
      expect(topic.errors[:featured_link]).to be_present
    end

    it 'can properly save the featured link' do
      topic.featured_link = '  https://github.com/discourse/discourse'

      expect(topic.save).to be_truthy
      expect(topic.featured_link).to eq('https://github.com/discourse/discourse')
    end

    context 'when category restricts present' do
      let!(:link_category) { Fabricate(:link_category) }
      fab!(:topic) { Fabricate(:topic) }
      let(:link_topic) { Fabricate(:topic, category: link_category) }

      it 'can save the featured link if it belongs to that category' do
        link_topic.featured_link = 'https://github.com/discourse/discourse'
        expect(link_topic.save).to be_truthy
        expect(link_topic.featured_link).to eq('https://github.com/discourse/discourse')
      end

      it 'can not save the featured link if category does not allow it' do
        topic.category = Fabricate(:category_with_definition, topic_featured_link_allowed: false)
        topic.featured_link = 'https://github.com/discourse/discourse'
        expect(topic.save).to be_falsey
      end

      it 'if category changes to disallow it, topic remains valid' do
        t = Fabricate(:topic, category: link_category, featured_link: "https://github.com/discourse/discourse")

        link_category.topic_featured_link_allowed = false
        link_category.save!
        t.reload

        expect(t.valid?).to eq(true)
      end
    end
  end

  describe '#time_to_first_response' do
    it "should have no results if no topics in range" do
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
    end

    it "should have no results if there is only a topic with no replies" do
      topic = Fabricate(:topic, created_at: 1.hour.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1)
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.time_to_first_response_total).to eq(0)
    end

    it "should have no results if reply is from first poster" do
      topic = Fabricate(:topic, created_at: 1.hour.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 2)
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.time_to_first_response_total).to eq(0)
    end

    it "should have results if there's a topic with replies" do
      topic = Fabricate(:topic, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, post_number: 2, created_at: 2.hours.ago)
      r = Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now)
      expect(r.count).to eq(1)
      expect(r[0]["hours"].to_f.round).to eq(1)
      expect(Topic.time_to_first_response_total).to eq(1)
    end

    it "should only count regular posts as the first response" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, post_number: 2, created_at: 4.hours.ago, post_type: Post.types[:whisper])
      Fabricate(:post, topic: topic, post_number: 3, created_at: 3.hours.ago, post_type: Post.types[:moderator_action])
      Fabricate(:post, topic: topic, post_number: 4, created_at: 2.hours.ago, post_type: Post.types[:small_action])
      Fabricate(:post, topic: topic, post_number: 5, created_at: 1.hour.ago)
      r = Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now)
      expect(r.count).to eq(1)
      expect(r[0]["hours"].to_f.round).to eq(4)
      expect(Topic.time_to_first_response_total).to eq(4)
    end
  end

  describe '#with_no_response' do
    it "returns nothing with no topics" do
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
    end

    it "returns 1 with one topic that has no replies" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 1 with one topic that has no replies and author was changed on first post" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: Fabricate(:user), post_number: 1, created_at: 5.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 1 with one topic that has a reply by the first poster" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 2, created_at: 2.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 0 with a topic with 1 reply" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      _post1 = Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      _post2 = Fabricate(:post, topic: topic, post_number: 2, created_at: 2.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.with_no_response_total).to eq(0)
    end

    it "returns 1 with one topic that doesn't have regular replies" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, post_number: 2, created_at: 4.hours.ago, post_type: Post.types[:whisper])
      Fabricate(:post, topic: topic, post_number: 3, created_at: 3.hours.ago, post_type: Post.types[:moderator_action])
      Fabricate(:post, topic: topic, post_number: 4, created_at: 2.hours.ago, post_type: Post.types[:small_action])
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end
  end

  describe '#pm_with_non_human_user?' do
    let(:robot) { Fabricate(:user, id: -3) }

    let(:topic) do
      topic = Fabricate(:private_message_topic,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: robot),
          Fabricate.build(:topic_allowed_user, user: user)
        ]
      )

      Fabricate(:post, topic: topic)
      topic
    end

    describe 'when PM is between a human and a non human user' do
      it 'should return true' do
        expect(topic.pm_with_non_human_user?).to be(true)
      end
    end

    describe 'when PM contains 2 human users and a non human user' do
      it 'should return false' do
        Fabricate(:topic_allowed_user, topic: topic, user: Fabricate(:user))

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end

    describe 'when PM only contains a user' do
      it 'should return true' do
        topic.topic_allowed_users.first.destroy!

        expect(topic.reload.pm_with_non_human_user?).to be(true)
      end
    end

    describe 'when PM contains a group' do
      it 'should return false' do
        Fabricate(:topic_allowed_group, topic: topic)

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end

    describe 'when topic is not a PM' do
      it 'should return false' do
        topic.convert_to_public_topic(Fabricate(:admin))

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end
  end

  describe '#remove_allowed_user' do
    fab!(:topic) { Fabricate(:topic) }

    describe 'removing oneself' do
      it 'should remove onself' do
        topic.allowed_users << another_user

        expect(topic.remove_allowed_user(another_user, another_user)).to eq(true)
        expect(topic.allowed_users.include?(another_user)).to eq(false)

        post = Post.last

        expect(post.user).to eq(Discourse.system_user)
        expect(post.post_type).to eq(Post.types[:small_action])
        expect(post.action_code).to eq('user_left')
      end
    end
  end

  describe '#featured_link_root_domain' do
    let(:topic) { Fabricate.build(:topic) }

    [
      "https://meta.discourse.org",
      "https://meta.discourse.org/",
      "https://meta.discourse.org/?filter=test",
      "https://meta.discourse.org/t/中國/1",
    ].each do |featured_link|
      it "should extract the root domain from #{featured_link} correctly" do
        topic.featured_link = featured_link
        expect(topic.featured_link_root_domain).to eq("discourse.org")
      end
    end
  end

  describe "#reset_bumped_at" do
    it "ignores hidden, deleted, moderator and small action posts when resetting the topic's bump date" do
      post1 = create_post(created_at: 10.hours.ago)
      topic = post1.topic

      expect { topic.reset_bumped_at }.to_not change { topic.bumped_at }

      post2 = Fabricate(:post, topic: topic, post_number: 2, created_at: 9.hours.ago)
      Fabricate(:post, topic: topic, post_number: 3, created_at: 8.hours.ago, deleted_at: 1.hour.ago)
      Fabricate(:post, topic: topic, post_number: 4, created_at: 7.hours.ago, hidden: true)
      Fabricate(:post, topic: topic, post_number: 5, created_at: 6.hours.ago, user_deleted: true)
      Fabricate(:post, topic: topic, post_number: 6, created_at: 5.hours.ago, post_type: Post.types[:whisper])

      expect { topic.reset_bumped_at }.to change { topic.bumped_at }.to(post2.reload.created_at)

      post3 = Fabricate(:post, topic: topic, post_number: 7, created_at: 4.hours.ago, post_type: Post.types[:regular])
      expect { topic.reset_bumped_at }.to change { topic.bumped_at }.to(post3.reload.created_at)

      Fabricate(:post, topic: topic, post_number: 8, created_at: 3.hours.ago, post_type: Post.types[:small_action])
      Fabricate(:post, topic: topic, post_number: 9, created_at: 2.hours.ago, post_type: Post.types[:moderator_action])
      expect { topic.reset_bumped_at }.not_to change { topic.bumped_at }
    end
  end

  describe "#access_topic_via_group" do
    let(:open_group) { Fabricate(:group, public_admission: true) }
    let(:request_group) do
      Fabricate(:group).tap do |g|
        g.add_owner(user)
        g.allow_membership_requests = true
        g.save!
      end
    end
    let(:category) { Fabricate(:category_with_definition) }
    let(:topic) { Fabricate(:topic, category: category) }

    it "returns a group that is open or accepts membership requests and has access to the topic" do
      expect(topic.access_topic_via_group).to eq(nil)

      category.set_permissions(request_group => :full)
      category.save!

      expect(topic.access_topic_via_group).to eq(request_group)

      category.set_permissions(request_group => :full, open_group => :full)
      category.save!

      expect(topic.access_topic_via_group).to eq(open_group)
    end
  end
end
