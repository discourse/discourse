# frozen_string_literal: true

require "post_creator"
require "topic_subtype"

RSpec.describe PostCreator do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }
  fab!(:evil_trout) { Fabricate(:evil_trout, refresh_auto_groups: true) }
  let(:topic) { Fabricate(:topic, user: user) }

  describe "whisper" do
    fab!(:topic) { Fabricate(:topic, user: user) }

    before { SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}" }

    it "whispers do not mess up the public view" do
      freeze_time_safe

      first = PostCreator.new(admin, topic_id: topic.id, raw: "this is the first post").create

      freeze_time 1.year.from_now

      user_stat = admin.user_stat

      whisper =
        PostCreator.new(
          admin,
          topic_id: topic.id,
          reply_to_post_number: first.post_number,
          post_type: Post.types[:whisper],
          raw: "this is a whispered reply",
        ).create

      # don't count whispers in user stats
      expect(user_stat.reload.post_count).to eq(0)

      expect(whisper).to be_present
      expect(whisper.post_type).to eq(Post.types[:whisper])

      whisper_reply =
        PostCreator.new(
          admin,
          topic_id: topic.id,
          reply_to_post_number: whisper.post_number,
          post_type: Post.types[:regular],
          raw: "replying to a whisper this time",
        ).create

      expect(whisper_reply).to be_present
      expect(whisper_reply.post_type).to eq(Post.types[:whisper])

      expect(user_stat.reload.post_count).to eq(0)

      admin.reload
      expect(admin.last_posted_at).to eq_time(1.year.ago)

      # date is not precise enough in db
      whisper_reply.reload

      first.reload
      # does not leak into the OP
      expect(first.reply_count).to eq(0)

      topic.reload

      # cause whispers should not muck up that number
      expect(topic.highest_post_number).to eq(1)
      expect(topic.reply_count).to eq(0)
      expect(topic.posts_count).to eq(1)
      expect(topic.highest_staff_post_number).to eq(3)
      expect(topic.last_posted_at).to eq_time(first.created_at)
      expect(topic.last_post_user_id).to eq(first.user_id)
      expect(topic.word_count).to eq(5)

      topic.update_columns(
        highest_staff_post_number: 0,
        highest_post_number: 0,
        posts_count: 0,
        word_count: 0,
        last_posted_at: 1.year.ago,
      )

      Topic.reset_highest(topic.id)

      topic.reload
      expect(topic.highest_post_number).to eq(1)
      expect(topic.posts_count).to eq(1)
      expect(topic.word_count).to eq(5)
      expect(topic.last_posted_at).to eq_time(first.created_at)
      expect(topic.highest_staff_post_number).to eq(3)
    end
  end

  describe "silent" do
    fab!(:topic) { Fabricate(:topic, user: user) }

    it "silent do not mess up the public view" do
      freeze_time_safe

      first = PostCreator.new(user, topic_id: topic.id, raw: "this is the first post").create

      freeze_time 1.year.from_now

      PostCreator.new(
        user,
        topic_id: topic.id,
        reply_to_post_number: 1,
        silent: true,
        post_type: Post.types[:regular],
        raw: "this is a whispered reply",
      ).create

      topic.reload

      # silent post should not muck up that number
      expect(topic.last_posted_at).to eq_time(first.created_at)
      expect(topic.last_post_user_id).to eq(first.user_id)
      expect(topic.word_count).to eq(5)
    end
  end

  describe "uniqueness" do
    fab!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: "test reply", topic_id: topic.id, reply_to_post_number: 4 } }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    context "when disabled" do
      before do
        SiteSetting.unique_posts_mins = 0
        creator.create
      end

      it "returns true for another post with the same content" do
        new_creator = PostCreator.new(user, basic_topic_params)
        expect(new_creator.create).to be_present
      end
    end

    context "when enabled" do
      let(:new_post_creator) { PostCreator.new(user, basic_topic_params) }

      before { SiteSetting.unique_posts_mins = 10 }

      it "fails for dupe post across topic" do
        first = create_post(raw: "this is a test #{SecureRandom.hex}")
        second = create_post(raw: "this is a test #{SecureRandom.hex}")

        dupe = "hello 123 test #{SecureRandom.hex}"

        response_1 = PostCreator.create(first.user, raw: dupe, topic_id: first.topic_id)
        response_2 = PostCreator.create(first.user, raw: dupe, topic_id: second.topic_id)

        expect(response_1.errors.count).to eq(0)
        expect(response_2.errors.count).to eq(1)
      end

      it "returns blank for another post with the same content" do
        creator.create
        post = new_post_creator.create

        expect(post.errors[:raw]).to include(I18n.t(:just_posted_that))
      end

      it "returns a post for admins" do
        creator.create
        user.admin = true
        new_post_creator.create
        expect(new_post_creator.errors).to be_blank
      end

      it "returns a post for moderators" do
        creator.create
        user.moderator = true
        new_post_creator.create
        expect(new_post_creator.errors).to be_blank
      end
    end
  end

  describe "host spam" do
    fab!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: "test reply", topic_id: topic.id, reply_to_post_number: 4 } }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    before { Post.any_instance.expects(:has_host_spam?).returns(true) }

    it "does not create the post" do
      GroupMessage.stubs(:create)
      _post = creator.create

      expect(creator.errors).to be_present
      expect(creator.spam?).to eq(true)
    end

    it "sends a message to moderators" do
      GroupMessage
        .expects(:create)
        .with do |group_name, msg_type, params|
          group_name == Group[:moderators].name && msg_type == :spam_post_blocked &&
            params[:user].id == user.id
        end
      creator.create
    end

    it "does not create a reviewable post if the review_every_post setting is enabled" do
      SiteSetting.review_every_post = true
      GroupMessage.stubs(:create)

      expect { creator.create }.not_to change(ReviewablePost, :count)
    end
  end

  # more integration testing ... maximise our testing
  describe "existing topic" do
    fab!(:topic) { Fabricate(:topic, user: user, title: "topic title with 25 chars") }
    let(:creator) do
      PostCreator.new(user, raw: "test reply", topic_id: topic.id, reply_to_post_number: 4)
    end

    it "ensures the user can create the post" do
      Guardian.any_instance.expects(:can_create?).with(Post, topic).returns(false)
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end

    context "with success" do
      it "create correctly" do
        post = creator.create
        expect(Post.count).to eq(1)
        expect(Topic.count).to eq(1)
        expect(post.reply_to_post_number).to eq(4)
      end
    end

    context "when the user has bookmarks with auto_delete_preference on_owner_reply" do
      before do
        Fabricate(
          :bookmark,
          user: user,
          bookmarkable: Fabricate(:post, topic: topic),
          auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
        )
        Fabricate(
          :bookmark,
          user: user,
          bookmarkable: Fabricate(:post, topic: topic),
          auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
        )
        TopicUser.create!(topic: topic, user: user, bookmarked: true)
      end

      it "deletes the bookmarks, but not the ones without an auto_delete_preference" do
        Fabricate(:bookmark, bookmarkable: Fabricate(:post, topic: topic), user: user)
        Fabricate(:bookmark, user: user)
        creator.create
        expect(Bookmark.where(user: user).count).to eq(2)
        expect(TopicUser.find_by(topic: topic, user: user).bookmarked).to eq(true)
      end

      context "when there are no bookmarks left in the topic" do
        it "sets TopicUser.bookmarked to false" do
          creator.create
          expect(TopicUser.find_by(topic: topic, user: user).bookmarked).to eq(false)
        end
      end
    end

    context "with topic stats" do
      before do
        PostCreator.new(
          coding_horror,
          raw: "first post in topic",
          topic_id: topic.id,
          created_at: 24.hours.ago,
        ).create
      end

      it "updates topic stats" do
        post = creator.create
        topic.reload

        expect(topic.last_posted_at).to eq_time(post.created_at)
        expect(topic.last_post_user_id).to eq(post.user_id)
        expect(topic.word_count).to eq(6)
      end

      it "publishes updates to topic stats" do
        reply_timestamp = 1.day.from_now.round

        # tests if messages of type :stats are published and the relevant data is fetched from the topic
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            PostCreator.new(
              evil_trout,
              raw: "other post in topic",
              topic_id: topic.id,
              created_at: reply_timestamp,
            ).create
          end

        stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
        expect(stats_message).to be_present
        expect(stats_message.data[:posts_count]).to eq(2)
        expect(stats_message.data[:last_posted_at]).to eq(reply_timestamp.as_json)
        expect(stats_message.data[:last_poster]).to eq(
          BasicUserSerializer.new(evil_trout, root: false).as_json,
        )
      end

      it "updates topic stats even when topic fails validation" do
        topic.update_columns(title: "below 15 chars")

        post = creator.create
        topic.reload

        expect(topic.last_posted_at).to eq_time(post.created_at)
        expect(topic.last_post_user_id).to eq(post.user_id)
        expect(topic.word_count).to eq(6)
      end
    end

    context "when the topic is in slow mode" do
      before do
        one_day = 86_400
        topic.update!(slow_mode_seconds: one_day)
      end

      it "fails if the user recently posted in this topic" do
        Fabricate(:post, topic: topic, user: user, created_at: 10.minutes.ago)

        post = creator.create

        expect(post).to be_blank
        expect(creator.errors.count).to eq 1
        expect(creator.errors.messages[:base][0]).to match I18n.t(:slow_mode_enabled)
      end

      it "creates the topic if the user last post is older than the slow mode interval" do
        Fabricate(:post, topic: topic, user: user, created_at: 5.days.ago)

        post = creator.create

        expect(post).to be_present
        expect(creator.errors.count).to be_zero
      end

      it "creates the topic if the user is a staff member" do
        post_creator =
          PostCreator.new(admin, raw: "test reply", topic_id: topic.id, reply_to_post_number: 4)
        Fabricate(:post, topic: topic, user: admin, created_at: 10.minutes.ago)

        post = post_creator.create

        expect(post).to be_present
        expect(post_creator.errors.count).to be_zero
      end
    end
  end

  describe "closed topic" do
    fab!(:topic) { Fabricate(:topic, user: user, closed: true) }
    let(:creator) do
      PostCreator.new(user, raw: "test reply", topic_id: topic.id, reply_to_post_number: 4)
    end

    it "responds with an error message" do
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end
  end

  describe "missing topic" do
    let(:topic) { Fabricate(:topic, user: user, deleted_at: 5.minutes.ago) }
    let(:creator) do
      PostCreator.new(user, raw: "test reply", topic_id: topic.id, reply_to_post_number: 4)
    end

    it "responds with an error message" do
      post = creator.create
      expect(post).to be_blank
      expect(creator.errors.count).to eq 1
      expect(creator.errors.messages[:base][0]).to match I18n.t(:topic_not_found)
    end
  end

  describe "cooking options" do
    let(:raw) { "this is my awesome message body hello world" }

    it "passes the cooking options through correctly" do
      creator =
        PostCreator.new(
          user,
          title: "hi there welcome to my topic",
          raw: raw,
          cooking_options: {
            traditional_markdown_linebreaks: true,
          },
        )

      Post
        .any_instance
        .expects(:cook)
        .with(raw, has_key(:traditional_markdown_linebreaks))
        .returns(raw)
      creator.create
    end
  end

  # integration test ... minimise db work
  describe "private message" do
    let(:target_user1) { coding_horror }
    fab!(:target_user2, :moderator)
    fab!(:unrelated_user, :user)
    let(:post) do
      PostCreator.create!(
        user,
        title: "hi there welcome to my topic",
        raw: "this is my awesome message @#{unrelated_user.username_lower}",
        archetype: Archetype.private_message,
        target_usernames: [target_user1.username, target_user2.username].join(","),
        category: 1,
      )
    end

    it "respects min_personal_message_post_length" do
      SiteSetting.min_personal_message_post_length = 5
      SiteSetting.min_first_post_length = 20
      SiteSetting.min_post_length = 25
      SiteSetting.body_min_entropy = 20
      user.change_trust_level!(TrustLevel[3])

      expect {
        PostCreator.create!(
          user,
          title: "hi there welcome to my PM",
          raw: "sorry",
          archetype: Archetype.private_message,
          target_usernames: [target_user1.username, target_user2.username].join(","),
          category: 1,
        )
      }.not_to raise_error
    end

    it "acts correctly" do
      freeze_time

      user.update_columns(last_posted_at: 1.year.ago)

      # It's not a warning
      expect(post.topic.user_warning).to be_blank

      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)
      expect(post.topic.topic_allowed_users.count).to eq(3)

      # PMs can't have a category
      expect(post.topic.category).to eq(nil)

      # does not notify an unrelated user
      expect(unrelated_user.notifications.count).to eq(0)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)

      # PMs do not increase post count or topic count
      expect(post.user.user_stat.post_count).to eq(0)
      expect(post.user.user_stat.topic_count).to eq(0)

      user.reload
      expect(user.last_posted_at).to eq_time(1.year.ago)

      # archive this message and ensure archive is cleared for all users on reply
      UserArchivedMessage.create(user_id: target_user2.id, topic_id: post.topic_id)

      # if an admin replies they should be added to the allowed user list
      PostCreator.create!(admin, raw: "hi there welcome topic, I am a mod", topic_id: post.topic_id)

      post.topic.reload
      expect(post.topic.topic_allowed_users.where(user_id: admin.id).count).to eq(1)

      expect(
        UserArchivedMessage.where(user_id: target_user2.id, topic_id: post.topic_id).count,
      ).to eq(0)

      # if another admin replies and is already member of the group, don't add them to topic_allowed_users
      group = Fabricate(:group)
      post.topic.topic_allowed_groups.create!(group: group)
      admin2 = Fabricate(:admin)
      group.add(admin2)

      PostCreator.create!(admin2, raw: "I am also an admin, and a mod", topic_id: post.topic_id)

      expect(post.topic.topic_allowed_users.where(user_id: admin2.id).count).to eq(0)

      tl0_user = Fabricate(:user, trust_level: 0, refresh_auto_groups: true)
      PostCreator.create!(
        tl0_user,
        raw: "Automated support reply",
        topic_id: post.topic_id,
        guardian: Discourse.system_user.guardian,
        skip_staff_author_pm_membership_sync: true,
      )

      expect(post.topic.topic_allowed_users.where(user_id: tl0_user.id).count).to eq(0)
    end

    it "does not add whisper authors to allowed users of the topic" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      unrelated_user.update!(admin: true)

      PostCreator.create!(
        unrelated_user,
        raw: "This is a whisper that I am testing",
        topic_id: post.topic_id,
        post_type: Post.types[:whisper],
      )

      expect(post.topic.topic_allowed_users.map(&:user_id)).to contain_exactly(
        target_user1.id,
        target_user2.id,
        user.id,
      )
    end

    it "does not add small-action authors to allowed users of the topic" do
      unrelated_user.update!(admin: true)

      PostCreator.create!(
        unrelated_user,
        raw: "This is a whisper that I am testing",
        topic_id: post.topic_id,
        post_type: Post.types[:small_action],
      )

      expect(post.topic.topic_allowed_users.map(&:user_id)).to contain_exactly(
        target_user1.id,
        target_user2.id,
        user.id,
      )
    end

    it "does not increase posts/words count for small actions" do
      topic = Fabricate(:private_message_topic, user: Fabricate(:user, refresh_auto_groups: true))

      p1 = Fabricate(:post, topic: topic)

      1.upto(3) do |i|
        user = Fabricate(:user)
        topic.invite(topic.user, user.username)
        topic.reload
        expect(topic.posts_count).to eq(1)
        expect(topic.posts.where(post_type: Post.types[:small_action]).count).to eq(i)
      end

      expect(topic.word_count).to be_nil

      p2 = Fabricate(:post, topic: topic)
      Topic.reset_highest(topic.id)
      topic.reload
      expect(topic.posts_count).to eq(2)
      expect(topic.word_count).to eq([p1, p2].sum(&:word_count))

      p3 = Fabricate(:post, topic: topic)
      Topic.reset_all_highest!
      topic.reload
      expect(topic.posts_count).to eq(3)
      expect(topic.word_count).to eq([p1, p2, p3].sum(&:word_count))
    end

    it "does not bump any post number counter for small_action posts" do
      topic = Fabricate(:private_message_topic, user: Fabricate(:user, refresh_auto_groups: true))
      Fabricate(:post, topic: topic)
      topic.reload

      expect(topic.highest_post_number).to eq(1)
      expect(topic.highest_staff_post_number).to eq(1)

      PostCreator.create!(
        Discourse.system_user,
        raw: "topic unlisted",
        topic_id: topic.id,
        post_type: Post.types[:small_action],
        action_code: "visible.disabled",
        skip_validations: true,
      )
      topic.reload

      expect(topic.highest_post_number).to eq(1)
      expect(topic.highest_staff_post_number).to eq(1)
    end
  end

  describe "warnings" do
    let(:target_user1) { coding_horror }
    fab!(:target_user2, :moderator)
    let(:base_args) do
      {
        title: "you need a warning buddy!",
        raw: "you did something bad and I'm telling you about it!",
        is_warning: true,
        target_usernames: target_user1.username,
        category: 1,
      }
    end

    it "works as expected" do
      # Invalid archetype
      creator = PostCreator.new(user, base_args)
      creator.create
      expect(creator.errors).to be_present

      # Too many users
      creator =
        PostCreator.new(
          user,
          base_args.merge(
            archetype: Archetype.private_message,
            target_usernames: [target_user1.username, target_user2.username].join(","),
          ),
        )
      creator.create
      expect(creator.errors).to be_present

      # Success
      creator = PostCreator.new(user, base_args.merge(archetype: Archetype.private_message))
      post = creator.create
      expect(creator.errors).to be_blank

      topic = post.topic
      expect(topic).to be_present
      expect(topic.user_warning).to be_present
      expect(topic.subtype).to eq(TopicSubtype.moderator_warning)
      expect(topic.user_warning.user).to eq(target_user1)
      expect(topic.user_warning.created_by).to eq(user)
      expect(target_user1.user_warnings.count).to eq(1)
    end
  end

  describe "auto closing" do
    it "closes private messages that have more than N posts" do
      SiteSetting.auto_close_messages_post_count = 2

      post1 = create_post(archetype: Archetype.private_message, target_usernames: [admin.username])

      expect do create_post(user: post1.user, topic_id: post1.topic_id) end.to change {
        Post.count
      }.by(2)

      post1.topic.reload

      expect(post1.topic.posts.last.raw).to eq(
        I18n.t(
          "topic_statuses.autoclosed_message_max_posts",
          count: SiteSetting.auto_close_messages_post_count,
        ),
      )

      expect(post1.topic.closed).to eq(true)
    end

    it "closes topics that have more than N posts" do
      SiteSetting.auto_close_topics_post_count = 2

      post1 = create_post

      expect do create_post(user: post1.user, topic_id: post1.topic_id) end.to change {
        Post.count
      }.by(2)

      post1.topic.reload

      expect(post1.topic.posts.last.raw).to eq(
        I18n.t(
          "topic_statuses.autoclosed_topic_max_posts",
          count: SiteSetting.auto_close_topics_post_count,
        ),
      )

      expect(post1.topic.closed).to eq(true)
    end
  end

  describe "private message with target_user_ids" do
    fab!(:target_user1) { coding_horror }
    fab!(:target_user2, :moderator)

    it "creates a PM targeting users by ID" do
      post =
        PostCreator.create!(
          user,
          title: "PM via user IDs",
          raw: "this is a PM sent using target_user_ids",
          archetype: Archetype.private_message,
          target_user_ids: [target_user1.id, target_user2.id],
        )

      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.allowed_users).to include(target_user1, target_user2, user)
    end

    it "raises when both target_usernames and target_user_ids are provided" do
      expect {
        PostCreator.create!(
          user,
          title: "PM with both",
          raw: "this should fail",
          archetype: Archetype.private_message,
          target_usernames: target_user1.username,
          target_user_ids: [target_user2.id],
        )
      }.to raise_error(ArgumentError, /Cannot specify both/)
    end
  end

  describe "private message to group" do
    fab!(:target_user1) { coding_horror }
    fab!(:target_user2, :moderator)
    let!(:group) do
      g = Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone])
      g.add(target_user1)
      g.add(target_user2)
      g
    end
    fab!(:unrelated, :user)
    let(:post) do
      PostCreator.create!(
        user,
        title: "hi there welcome to my topic",
        raw: "this is my awesome message @#{unrelated.username_lower}",
        archetype: Archetype.private_message,
        target_group_names: group.name,
      )
    end

    it "can post to a group correctly" do
      Jobs.run_immediately!

      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.topic_allowed_users.count).to eq(1)
      expect(post.topic.topic_allowed_groups.count).to eq(1)

      # does not notify an unrelated user
      expect(unrelated.notifications.count).to eq(0)
      expect(post.topic.subtype).to eq(TopicSubtype.user_to_user)

      expect(target_user1.notifications.count).to eq(1)
      expect(target_user2.notifications.count).to eq(1)

      GroupArchivedMessage.create!(group: group, topic: post.topic)

      message =
        MessageBus
          .track_publish(PrivateMessageTopicTrackingState.group_channel(group.id)) do
            PostCreator.create!(
              user,
              raw: "this is a reply to the group message",
              topic_id: post.topic_id,
            )
          end
          .first

      expect(message.data["message_type"]).to eq(
        PrivateMessageTopicTrackingState::GROUP_ARCHIVE_MESSAGE_TYPE,
      )

      expect(message.data["payload"]["acting_user_id"]).to eq(user.id)

      expect(GroupArchivedMessage.exists?(group: group, topic: post.topic)).to eq(false)
    end
  end

  describe "setting created_at" do
    it "supports Time instances" do
      freeze_time

      post1 =
        PostCreator.create(
          user,
          raw: "This is very interesting test post content",
          title: "This is a very interesting test post title",
          created_at: 1.week.ago,
        )
      topic = post1.topic

      post2 =
        PostCreator.create(
          user,
          raw: "This is very interesting test post content",
          topic_id: topic,
          created_at: 1.week.ago,
        )

      expect(post1.created_at).to eq_time(1.week.ago)
      expect(post2.created_at).to eq_time(1.week.ago)
      expect(topic.created_at).to eq_time(1.week.ago)
    end

    it "supports strings" do
      freeze_time

      time = Time.zone.parse("2019-09-02")

      post1 =
        PostCreator.create(
          user,
          raw: "This is very interesting test post content",
          title: "This is a very interesting test post title",
          created_at: "2019-09-02",
        )
      topic = post1.topic

      post2 =
        PostCreator.create(
          user,
          raw: "This is very interesting test post content",
          topic_id: topic,
          created_at: "2019-09-02 00:00:00 UTC",
        )

      expect(post1.created_at).to eq_time(time)
      expect(post2.created_at).to eq_time(time)
      expect(topic.created_at).to eq_time(time)
    end
  end

  describe "disable validations" do
    it "can save a post" do
      creator = PostCreator.new(user, raw: "q", title: "q", skip_validations: true)
      creator.create
      expect(creator.errors).to be_blank
    end
  end

  describe "word_count" do
    it "has a word count" do
      creator =
        PostCreator.new(
          user,
          title: "some inspired poetry for a rainy day",
          raw:
            "mary had a little lamb, little lamb, little lamb. mary had a little lamb. Здравствуйте",
        )
      post = creator.create
      expect(post.word_count).to eq(15)

      post.topic.reload
      expect(post.topic.word_count).to eq(15)
    end
  end

  describe "embed_url" do
    let(:embed_url) { "http://eviltrout.com/stupid-url" }

    it "creates the topic_embed record" do
      creator =
        PostCreator.new(
          user,
          embed_url: embed_url,
          title: "Reviews of Science Ovens",
          raw: "Did you know that you can use microwaves to cook your dinner? Science!",
        )
      creator.create
      expect(creator.errors).to be_blank
      expect(TopicEmbed.where(embed_url: embed_url).exists?).to eq(true)
    end

    it "does not create topics with the same embed url" do
      PostCreator.create(
        user,
        embed_url: embed_url,
        title: "Reviews of Science Ovens",
        raw: "Did you know that you can use microwaves to cook your dinner? Science!",
      )
      creator =
        PostCreator.new(
          user,
          embed_url: embed_url,
          title: "More Reviews of Science Ovens",
          raw: "As if anyone ever wanted to learn more about them!",
        )
      result = creator.create
      expect(result).to be_present
      expect(creator.errors).to be_present
    end

    it "sets the embed content sha1" do
      content = "Did you know that you can use microwaves to cook your dinner? Science!"
      content_sha1 = Digest::SHA1.hexdigest(content)
      creator =
        PostCreator.new(
          user,
          embed_url: embed_url,
          embed_content_sha1: content_sha1,
          title: "Reviews of Science Ovens",
          raw: content,
        )
      creator.create
      expect(creator.errors).to be_blank
      expect(TopicEmbed.where(content_sha1: content_sha1).exists?).to eq(true)
    end

    context "when embed_unlisted is true" do
      before { SiteSetting.embed_unlisted = true }

      it "unlists the topic" do
        creator =
          PostCreator.new(
            user,
            embed_url: embed_url,
            title: "Reviews of Science Ovens",
            raw: "Did you know that you can use microwaves to cook your dinner? Science!",
          )
        post = creator.create
        expect(creator.errors).to be_blank
        expect(post.topic).not_to be_visible
      end
    end

    it "normalizes the embed url" do
      embed_url = "http://eviltrout.com/stupid-url/"
      creator =
        PostCreator.new(
          user,
          embed_url: embed_url,
          title: "Reviews of Science Ovens",
          raw: "Did you know that you can use microwaves to cook your dinner? Science!",
        )
      creator.create
      expect(creator.errors).to be_blank
      expect(TopicEmbed.where(embed_url: "http://eviltrout.com/stupid-url").exists?).to eq(true)
    end
  end

  describe "read credit for creator" do
    it "gives credit to creator" do
      post = create_post
      expect(
        PostTiming.find_by(
          topic_id: post.topic_id,
          post_number: post.post_number,
          user_id: post.user_id,
        ).msecs,
      ).to be > 0

      expect(
        TopicUser.find_by(topic_id: post.topic_id, user_id: post.user_id).last_read_post_number,
      ).to eq(1)
    end
  end

  describe "suspended users" do
    it "does not allow suspended users to create topics" do
      user = Fabricate(:user, suspended_at: 1.month.ago, suspended_till: 1.month.from_now)

      creator =
        PostCreator.new(user, title: "my test title 123", raw: "I should not be allowed to post")
      creator.create
      expect(creator.errors.count).to be > 0
    end
  end

  it "doesn't strip starting whitespaces" do
    pc =
      PostCreator.new(
        user,
        title: "testing whitespace stripping",
        raw: "    <-- whitespaces -->    ",
      )
    post = pc.create
    expect(post.raw).to eq("    <-- whitespaces -->")
  end

  describe "events" do
    let(:event_counts) { { posts: 0, topics: 0 } }
    let(:increase_posts) { ->(_post, _opts, _user) { event_counts[:posts] += 1 } }
    let(:increase_topics) { ->(_topic, _opts, _user) { event_counts[:topics] += 1 } }

    before do
      DiscourseEvent.on(:post_created, &increase_posts)
      DiscourseEvent.on(:topic_created, &increase_topics)
    end

    after do
      DiscourseEvent.off(:post_created, &increase_posts)
      DiscourseEvent.off(:topic_created, &increase_topics)
    end

    it "fires both event when creating a topic" do
      pc =
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      _post = pc.create
      expect(event_counts[:posts]).to eq(1)
      expect(event_counts[:topics]).to eq(1)
    end

    it "fires only the post event when creating a post" do
      pc = PostCreator.new(user, topic_id: topic.id, raw: "this is the new content for my post")
      _post = pc.create
      expect(event_counts[:posts]).to eq(1)
      expect(event_counts[:topics]).to eq(0)
    end

    it "fires post_created even when topic_created handler raises" do
      bad_handler = proc { raise "topic_created boom" }
      DiscourseEvent.on(:topic_created, &bad_handler)

      PostCreator.new(
        user,
        raw: "this is the new content for my topic",
        title: "this is my new topic title",
      ).create

      expect(event_counts[:posts]).to eq(1)
    ensure
      DiscourseEvent.off(:topic_created, &bad_handler)
    end
  end

  describe "staged users" do
    fab!(:staged) { Fabricate(:staged, refresh_auto_groups: true) }

    it "automatically watches all messages it participates in" do
      post =
        PostCreator.create(
          staged,
          title: "this is the title of a topic created by a staged user",
          raw: "this is the content of a topic created by a staged user ;)",
        )
      topic_user = TopicUser.find_by(user_id: staged.id, topic_id: post.topic_id)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:watching])
      expect(topic_user.notifications_reason_id).to eq(TopicUser.notification_reasons[:auto_watch])
    end
  end

  describe "topic tracking" do
    it "automatically watches topic based on preference" do
      user.user_option.notification_level_when_replying = 3

      topic =
        PostCreator.create(
          admin,
          title: "this is the title of a topic created by an admin for watching notification",
          raw:
            "this is the content of a topic created by an admin for keeping a watching notification state on a topic ;)",
        )

      post =
        PostCreator.create(
          user,
          topic_id: topic.topic_id,
          raw: "this is a reply to set the tracking state to watching ;)",
        )
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: post.topic_id)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:watching])
    end

    it "topic notification level remains tracking based on preference" do
      user.user_option.notification_level_when_replying = 2

      topic =
        PostCreator.create(
          admin,
          title: "this is the title of a topic created by an admin for tracking notification",
          raw:
            "this is the content of a topic created by an admin for keeping a tracking notification state on a topic ;)",
        )

      post =
        PostCreator.create(
          user,
          topic_id: topic.topic_id,
          raw: "this is a reply to set the tracking state to tracking ;)",
        )
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: post.topic_id)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:tracking])
    end

    it "topic notification level is normal based on preference" do
      user.user_option.notification_level_when_replying = 1

      topic =
        PostCreator.create(
          admin,
          title: "this is the title of a topic created by an admin for tracking notification",
          raw:
            "this is the content of a topic created by an admin for keeping a tracking notification state on a topic ;)",
        )

      post =
        PostCreator.create(
          user,
          topic_id: topic.topic_id,
          raw: "this is a reply to set the tracking state to normal ;)",
        )
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: post.topic_id)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:regular])
    end

    it "user preferences for notification level when replying doesn't affect PMs" do
      user.user_option.update!(notification_level_when_replying: 1)

      pm = Fabricate(:private_message_topic, user: admin)

      pm.invite(admin, user.username)
      PostCreator.create(user, topic_id: pm.id, raw: "this is a test reply 123 123 ;)")
      topic_user = TopicUser.find_by(user_id: user.id, topic_id: pm.id)
      expect(topic_user.notification_level).to eq(3)
    end

    it "sets the last_posted_at timestamp to track the last time the user posted" do
      topic = Fabricate(:topic)

      PostCreator.create(user, topic_id: topic.id, raw: "this is a test reply 123 123 ;)")

      topic_user = TopicUser.find_by(user_id: user.id, topic_id: topic.id)
      expect(topic_user.last_posted_at).to be_present
    end
  end

  describe "#create!" do
    it "returns the post if it was successfully created" do
      title = "This is a valid title"
      raw = "This is a really awesome post"

      post_creator = PostCreator.new(user, title: title, raw: raw)
      post = post_creator.create

      expect(post).to eq(Post.last)
      expect(post.topic.title).to eq(title)
      expect(post.raw).to eq(raw)
    end

    it "raises an error when post fails to be created" do
      post_creator = PostCreator.new(user, title: "", raw: "")
      expect { post_creator.create! }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it "does not generate an alert for empty posts" do
      Jobs.run_immediately!

      user2 = Fabricate(:user)
      topic =
        Fabricate(
          :private_message_topic,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: user),
            Fabricate.build(:topic_allowed_user, user: user2),
          ],
        )
      Fabricate(
        :topic_user,
        topic: topic,
        user: user2,
        notification_level: TopicUser.notification_levels[:watching],
      )

      expect {
        PostCreator.create!(user, raw: "", topic_id: topic.id, skip_validations: true)
      }.not_to change { user2.notifications.count }

      expect {
        PostCreator.create!(user, raw: "hello world", topic_id: topic.id, skip_validations: true)
      }.to change { user2.notifications.count }.by(1)
    end
  end

  describe "private message to a user that has disabled private messages" do
    fab!(:another_user) { Fabricate(:user, username: "HelloWorld") }

    before { another_user.user_option.update!(allow_private_messages: false) }

    it "is not valid" do
      post_creator =
        PostCreator.new(
          user,
          title: "this message is to someone who muted me!",
          raw: "you will have to see this even if you muted me!",
          archetype: Archetype.private_message,
          target_usernames: "#{another_user.username}",
        )

      expect(post_creator).to_not be_valid

      expect(post_creator.errors.full_messages).to include(
        I18n.t("not_accepting_pms", username: another_user.username),
      )
    end

    it "is not valid if the name is downcased" do
      post_creator =
        PostCreator.new(
          user,
          title: "this message is to someone who muted me!",
          raw: "you will have to see this even if you muted me!",
          archetype: Archetype.private_message,
          target_usernames: "#{another_user.username.downcase}",
        )

      expect(post_creator).to_not be_valid
    end
  end

  describe "private message to a muted user" do
    fab!(:muted_me) { evil_trout }
    fab!(:another_user, :user)

    it "rejects the private message" do
      updater = UserUpdater.new(muted_me, muted_me)
      updater.update_muted_users("#{user.username}")

      pc =
        PostCreator.new(
          user,
          title: "this message is to someone who muted me!",
          raw: "you will have to see this even if you muted me!",
          archetype: Archetype.private_message,
          target_usernames: "#{muted_me.username},#{another_user.username}",
        )

      expect(pc).not_to be_valid

      expect(pc.errors.full_messages).to contain_exactly(
        I18n.t(:not_accepting_pms, username: muted_me.username),
      )
    end

    fab!(:staff_user, :admin)

    it "succeeds if the user is staff" do
      updater = UserUpdater.new(muted_me, muted_me)
      updater.update_muted_users("#{staff_user.username}")

      pc =
        PostCreator.new(
          staff_user,
          title: "this message is to someone who muted me!",
          raw: "you will have to see this even if you muted me!",
          archetype: Archetype.private_message,
          target_usernames: "#{muted_me.username}",
        )
      expect(pc).to be_valid
      expect(pc.errors).to be_blank
    end
  end

  describe "private message to an ignored user" do
    fab!(:ignorer) { evil_trout }
    fab!(:another_user, :user)

    context "when post author is ignored" do
      before { Fabricate(:ignored_user, user: ignorer, ignored_user: user) }

      it "rejects the private message" do
        pc =
          PostCreator.new(
            user,
            title: "this message is to someone who ignored me!",
            raw: "you will have to see this even if you ignored me!",
            archetype: Archetype.private_message,
            target_usernames: "#{ignorer.username},#{another_user.username}",
          )

        expect(pc).not_to be_valid
        expect(pc.errors.full_messages).to contain_exactly(
          I18n.t(:not_accepting_pms, username: ignorer.username),
        )
      end
    end

    context "when post author is admin who is ignored" do
      fab!(:staff_user, :admin)
      fab!(:ignored_user) { Fabricate(:ignored_user, user: ignorer, ignored_user: staff_user) }

      it "succeeds if the user is staff" do
        pc =
          PostCreator.new(
            staff_user,
            title: "this message is to someone who ignored me!",
            raw: "you will have to see this even if you ignored me!",
            archetype: Archetype.private_message,
            target_usernames: "#{ignorer.username}",
          )
        expect(pc).to be_valid
        expect(pc.errors).to be_blank
      end
    end
  end

  describe "private message to user in allow list" do
    fab!(:sender) { evil_trout }
    fab!(:allowed_user, :user)

    context "when post author is allowed" do
      before do
        Fabricate(:allowed_pm_user, user: allowed_user, allowed_pm_user: sender)
      end

      it "allows the private message" do
        allowed_user.user_option.update!(enable_allowed_pm_users: true)

        pc =
          PostCreator.new(
            sender,
            title: "this message is to someone who is in my allow list!",
            raw: "you will have to see this because I'm in your allow list!",
            archetype: Archetype.private_message,
            target_usernames: "#{allowed_user.username}",
          )

        expect(pc).to be_valid
        expect(pc.errors).to be_blank
      end
    end

    context "when personal messages are disabled" do
      before do
        Fabricate(:allowed_pm_user, user: allowed_user, allowed_pm_user: sender)
      end

      it "rejects the private message" do
        allowed_user.user_option.update!(allow_private_messages: false)
        allowed_user.user_option.update!(enable_allowed_pm_users: true)

        pc =
          PostCreator.new(
            sender,
            title: "this message is to someone who is in my allow list!",
            raw: "you will have to see this because I'm in your allow list!",
            archetype: Archetype.private_message,
            target_usernames: "#{allowed_user.username}",
          )

        expect(pc).not_to be_valid
        expect(pc.errors.full_messages).to contain_exactly(
          I18n.t(:not_accepting_pms, username: allowed_user.username),
        )
      end
    end
  end

  describe "private message to user not in allow list" do
    fab!(:sender) { evil_trout }
    fab!(:allowed_user, :user)
    fab!(:not_allowed_user, :user)

    context "when post author is not allowed" do
      before do
        Fabricate(:allowed_pm_user, user: not_allowed_user, allowed_pm_user: allowed_user)
      end

      it "rejects the private message" do
        not_allowed_user.user_option.update!(enable_allowed_pm_users: true)

        pc =
          PostCreator.new(
            sender,
            title: "this message is to someone who is not in my allowed list!",
            raw: "you will have to see this even if you don't want message from me!",
            archetype: Archetype.private_message,
            target_usernames: "#{not_allowed_user.username}",
          )

        expect(pc).not_to be_valid
        expect(pc.errors.full_messages).to contain_exactly(
          I18n.t(:not_accepting_pms, username: not_allowed_user.username),
        )
      end

      it "succeeds when not enabled" do
        not_allowed_user.user_option.update!(enable_allowed_pm_users: false)

        pc =
          PostCreator.new(
            sender,
            title: "this message is to someone who is not in my allowed list!",
            raw: "you will have to see this even if you don't want message from me!",
            archetype: Archetype.private_message,
            target_usernames: "#{not_allowed_user.username}",
          )

        expect(pc).to be_valid
        expect(pc.errors).to be_blank
      end
    end
  end

  describe "private message when post author is admin who is not in allow list" do
    fab!(:staff_user, :admin)
    fab!(:allowed_user, :user)
    fab!(:not_allowed_user, :user)
    fab!(:allowed_pm_user) do
      Fabricate(:allowed_pm_user, user: staff_user, allowed_pm_user: allowed_user)
    end

    it "succeeds if the user is staff" do
      pc =
        PostCreator.new(
          staff_user,
          title: "this message is to someone who did not allow me!",
          raw: "you will have to see this even if you did not allow me!",
          archetype: Archetype.private_message,
          target_usernames: "#{not_allowed_user.username}",
        )
      expect(pc).to be_valid
      expect(pc.errors).to be_blank
    end
  end

  describe "private message to multiple users and one is not allowed" do
    fab!(:sender) { evil_trout }
    fab!(:allowed_user, :user)
    fab!(:not_allowed_user, :user)

    context "when post author is not allowed" do
      before do
        Fabricate(:allowed_pm_user, user: allowed_user, allowed_pm_user: sender)
      end

      it "rejects the private message" do
        allowed_user.user_option.update!(enable_allowed_pm_users: true)
        not_allowed_user.user_option.update!(enable_allowed_pm_users: true)

        pc =
          PostCreator.new(
            sender,
            title: "this message is to someone who is not in my allowed list!",
            raw: "you will have to see this even if you don't want message from me!",
            archetype: Archetype.private_message,
            target_usernames: "#{allowed_user.username},#{not_allowed_user.username}",
          )

        expect(pc).not_to be_valid
        expect(pc.errors.full_messages).to contain_exactly(
          I18n.t(:not_accepting_pms, username: not_allowed_user.username),
        )
      end
    end
  end

  describe "private message recipients limit (max_allowed_message_recipients) reached" do
    fab!(:target_user1) { coding_horror }
    fab!(:target_user2) { evil_trout }
    fab!(:target_user3, :walter_white)

    before { SiteSetting.max_allowed_message_recipients = 2 }

    context "for normal user" do
      it "fails when sending message to multiple recipients" do
        pc =
          PostCreator.new(
            user,
            title: "this message is for multiple recipients!",
            raw: "Lorem ipsum dolor sit amet, id elitr praesent mea, ut ius facilis fierent.",
            archetype: Archetype.private_message,
            target_usernames: [
              target_user1.username,
              target_user2.username,
              target_user3.username,
            ].join(","),
          )
        expect(pc).not_to be_valid
        expect(pc.errors).to be_present
      end

      it "succeeds when sending message to multiple recipients if skip_validations is true" do
        pc =
          PostCreator.new(
            user,
            title: "this message is for multiple recipients!",
            raw: "Lorem ipsum dolor sit amet, id elitr praesent mea, ut ius facilis fierent.",
            archetype: Archetype.private_message,
            target_usernames: [
              target_user1.username,
              target_user2.username,
              target_user3.username,
            ].join(","),
            skip_validations: true,
          )
        expect(pc).to be_valid
        expect(pc.errors).to be_blank
      end
    end

    context "if the user is staff" do
      fab!(:staff_user, :admin)

      it "succeeds when sending message to multiple recipients" do
        pc =
          PostCreator.new(
            staff_user,
            title: "this message is for multiple recipients!",
            raw: "Lorem ipsum dolor sit amet, id elitr praesent mea, ut ius facilis fierent.",
            archetype: Archetype.private_message,
            target_usernames: [
              target_user1.username,
              target_user2.username,
              target_user3.username,
            ].join(","),
          )
        expect(pc).to be_valid
        expect(pc.errors).to be_blank
      end
    end
  end

  describe "#create_post_notice" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:staged) { Fabricate(:staged, refresh_auto_groups: true) }
    fab!(:anonymous) { Fabricate(:anonymous, refresh_auto_groups: true) }

    it "generates post notices for new users" do
      post =
        PostCreator.create!(user, title: "one of my first topics", raw: "one of my first posts")
      expect(post.custom_fields[Post::NOTICE]).to eq("type" => Post.notices[:new_user])

      post =
        PostCreator.create!(
          user,
          title: "another one of my first topics",
          raw: "another one of my first posts",
        )
      expect(post.custom_fields[Post::NOTICE]).to eq(nil)
    end

    it "generates post notices for returning users" do
      SiteSetting.returning_users_days = 30
      old_post = Fabricate(:post, user: user, created_at: 31.days.ago)

      post = PostCreator.create!(user, title: "this is a returning topic", raw: "this is a post")
      expect(post.custom_fields[Post::NOTICE]).to eq(
        "type" => Post.notices[:returning_user],
        "last_posted_at" => old_post.created_at.iso8601,
      )

      post =
        PostCreator.create!(user, title: "this is another topic", raw: "this is my another post")
      expect(post.custom_fields[Post::NOTICE]).to eq(nil)
    end

    it "does not generate for non-human, staged or anonymous users" do
      SiteSetting.allow_anonymous_mode = true

      [anonymous, Discourse.system_user, staged].each do |user|
        expect(user.posts.size).to eq(0)
        post =
          PostCreator.create!(
            user,
            title: "#{user.username}'s first topic",
            raw: "#{user.name}'s first post",
          )
        expect(post.custom_fields[Post::NOTICE]).to eq(nil)
      end
    end
  end

  describe "secure uploads" do
    fab!(:image_upload) { Fabricate(:upload, secure: true) }
    fab!(:user2, :user)
    fab!(:public_topic, :topic)

    before do
      setup_s3
      SiteSetting.authorized_extensions = "png|jpg|gif|mp4"
      SiteSetting.secure_uploads = true
      stub_upload(image_upload)
    end

    it "links post uploads" do
      public_post =
        PostCreator.create(
          user,
          topic_id: public_topic.id,
          raw: "A public post with an image.\n![secure image](#{image_upload.short_path})",
        )
      expect(public_post.reload.uploads.map(&:access_control_post_id)).to eq([public_post.id])
    end
  end

  describe "queue for review" do
    before { SiteSetting.review_every_post = true }

    it "created a reviewable post after creating the post" do
      title = "This is a valid title"
      raw = "This is a really awesome post"

      post_creator = PostCreator.new(user, title: title, raw: raw)

      expect { post_creator.create }.to change(ReviewablePost, :count).by(1)
    end

    it "does not create a reviewable post if the post is not valid" do
      post_creator = PostCreator.new(user, title: "", raw: "")

      expect { post_creator.create }.not_to change(ReviewablePost, :count)
    end
  end

  context "when the review_every_post setting is enabled and category requires topic approval" do
    fab!(:category)

    before do
      category.require_topic_approval = true
      category.save!
      SiteSetting.review_every_post = true
    end

    it "creates single reviewable item" do
      manager =
        NewPostManager.new(
          user,
          title: "this is a new title",
          raw: "this is a new post",
          category: category.id,
        )
      reviewable = manager.perform.reviewable

      expect { reviewable.perform(admin, :approve_post) }.not_to change(ReviewablePost, :count)
    end
  end

  describe "draft cleanup" do
    it "deletes the draft after successful post creation" do
      topic = Fabricate(:topic)
      draft_key = topic.draft_key
      Draft.set(user, draft_key, 0, '{"reply":"test draft"}')

      expect(Draft.find_by(user_id: user.id, draft_key: draft_key)).to be_present

      PostCreator.create(
        user,
        topic_id: topic.id,
        raw: "reply content for testing",
        advance_draft: true,
      )

      expect(Draft.find_by(user_id: user.id, draft_key: draft_key)).to be_nil
    end

    it "deletes the draft even when draft sequence exceeds DraftSequence" do
      topic = Fabricate(:topic)
      draft_key = topic.draft_key

      # Simulate edge case: draft sequence is higher than DraftSequence
      Draft.create!(user: user, draft_key: draft_key, data: '{"reply":"test"}', sequence: 6)
      DraftSequence.create!(user_id: user.id, draft_key: draft_key, sequence: 5)

      expect(Draft.find_by(user_id: user.id, draft_key: draft_key)).to be_present

      PostCreator.create(
        user,
        topic_id: topic.id,
        raw: "reply content for testing",
        advance_draft: true,
      )

      expect(Draft.find_by(user_id: user.id, draft_key: draft_key)).to be_nil
    end
  end
end
