# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::AdvancedUserNarrative do
  fab!(:narrative_bot) { ::DiscourseNarrativeBot::Base.new }
  fab!(:discobot_user) { narrative_bot.discobot_user }
  fab!(:discobot_username) { narrative_bot.discobot_username }
  fab!(:first_post) { Fabricate(:post, user: discobot_user) }
  fab!(:user) { Fabricate(:user) }

  fab!(:topic) do
    Fabricate(
      :private_message_topic,
      first_post: first_post,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: discobot_user),
        Fabricate.build(:topic_allowed_user, user: user),
      ],
    )
  end

  fab!(:post) { Fabricate(:post, topic: topic, user: user) }
  fab!(:narrative) { described_class.new }
  fab!(:other_topic) { Fabricate(:topic) }
  fab!(:other_post) { Fabricate(:post, topic: other_topic) }
  fab!(:skip_trigger) { DiscourseNarrativeBot::TrackSelector.skip_trigger }
  fab!(:reset_trigger) { DiscourseNarrativeBot::TrackSelector.reset_trigger }

  before do
    stub_image_size
    Jobs.run_immediately!
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  describe "#notify_timeout" do
    before do
      narrative.set_data(user, state: :tutorial_poll, topic_id: topic.id, last_post_id: post.id)
    end

    it "should create the right message" do
      expect { narrative.notify_timeout(user) }.to change { Post.count }.by(1)

      expect(Post.last.raw).to eq(
        I18n.t(
          "discourse_narrative_bot.timeout.message",
          username: user.username,
          skip_trigger: skip_trigger,
          reset_trigger: "#{reset_trigger} #{described_class.reset_trigger}",
          base_uri: "",
        ),
      )
    end
  end

  describe "#reset_bot" do
    before { narrative.set_data(user, state: :tutorial_images, topic_id: topic.id) }

    context "when trigger is initiated in a PM" do
      let(:user) { Fabricate(:user) }

      let(:topic) do
        topic_allowed_user = Fabricate.build(:topic_allowed_user, user: user)
        bot = Fabricate.build(:topic_allowed_user, user: discobot_user)
        Fabricate(:private_message_topic, topic_allowed_users: [topic_allowed_user, bot])
      end

      let(:post) { Fabricate(:post, topic: topic) }

      it "should reset the bot" do
        narrative.reset_bot(user, post)

        expected_raw =
          I18n.t(
            "discourse_narrative_bot.advanced_user_narrative.start_message",
            username: user.username,
            base_uri: "",
          )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t("discourse_narrative_bot.advanced_user_narrative.edit.instructions", base_uri: "")}
        RAW

        new_post = topic.ordered_posts.last(2).first

        expect(narrative.get_data(user)).to eq(
          "topic_id" => topic.id,
          "state" => "tutorial_edit",
          "last_post_id" => new_post.id,
          "track" => described_class.to_s,
          "tutorial_edit" => {
            "post_id" => Post.last.id,
          },
        )

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(new_post.topic.id).to eq(topic.id)
      end
    end

    context "when trigger is not initiated in a PM" do
      it "should start the new track in a PM" do
        narrative.reset_bot(user, other_post)

        expected_raw =
          I18n.t(
            "discourse_narrative_bot.advanced_user_narrative.start_message",
            username: user.username,
            base_uri: "",
          )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t("discourse_narrative_bot.advanced_user_narrative.edit.instructions", base_uri: "")}
        RAW

        new_post = Topic.last.ordered_posts.last(2).first

        expect(narrative.get_data(user)).to eq(
          "topic_id" => new_post.topic.id,
          "state" => "tutorial_edit",
          "last_post_id" => new_post.id,
          "track" => described_class.to_s,
          "tutorial_edit" => {
            "post_id" => Post.last.id,
          },
        )

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(new_post.topic.id).to_not eq(topic.id)
      end

      it "should not explode if title emojis are disabled" do
        SiteSetting.max_emojis_in_title = 0
        narrative.reset_bot(user, other_post)

        expect(Topic.last.title).to eq(
          I18n.t("discourse_narrative_bot.advanced_user_narrative.title"),
        )
      end
    end
  end

  describe "#input" do
    context "when editing tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_edit,
          topic_id: topic.id,
          track: described_class.to_s,
          tutorial_edit: {
            post_id: first_post.id,
          },
        )
      end

      context "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_edit)
        end
      end

      context "when user replies to the post" do
        it "should create the right reply" do
          post
          narrative.expects(:enqueue_timeout_job).with(user).once

          expect { narrative.input(:reply, user, post: post) }.to change { Post.count }.by(1)

          expect(Post.last.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.edit.not_found",
              url: first_post.url,
              base_uri: "",
            ),
          )
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: "@#{discobot_username} #{skip_trigger.upcase}")
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.delete.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
          end
        end
      end

      context "when user edits the right post" do
        let(:post_2) { Fabricate(:post, user: post.user, topic: post.topic) }

        it "should create the right reply" do
          post_2

          expect do
            PostRevisor.new(post_2).revise!(post_2.user, raw: "something new")
          end.to change { Post.count }.by(1)

          expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.edit.reply", base_uri: "")}

          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.delete.instructions", base_uri: "")}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end
      end
    end

    context "when deleting tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_delete,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.delete.not_found",
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger.upcase)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = topic.ordered_posts.last(2).first

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.recover.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
          end
        end
      end

      context "when user destroys a post in a different topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          PostDestroyer.new(user, other_post).destroy

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end
      end

      context "when user deletes a post in the right topic" do
        it "should create the right reply" do
          post

          expect { PostDestroyer.new(user, post).destroy }.to change { Post.count }.by(2)

          expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.delete.reply", base_uri: "")}

          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.recover.instructions", base_uri: "")}
          RAW

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
          expect(topic.ordered_posts.last(2).first.raw).to eq(expected_raw.chomp)
        end

        context "when user is an admin" do
          it "should create the right reply" do
            post
            user.update!(admin: true)

            expect { PostDestroyer.new(user, post).destroy }.to_not change { Post.count }

            expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.delete.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.recover.instructions", base_uri: "")}
            RAW

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
            expect(Post.last.raw).to eq(expected_raw.chomp)
          end
        end
      end
    end

    context "when undeleting post tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_recover,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      context "when posts are configured to be deleted immediately" do
        before { SiteSetting.delete_removed_posts_after = 0 }

        it "should set up the tutorial correctly" do
          narrative.set_data(
            user,
            state: :tutorial_delete,
            topic_id: topic.id,
            track: described_class.to_s,
          )

          PostDestroyer.new(user, post).destroy

          post = Post.last

          expect(post.raw).to eq(I18n.t("js.post.deleted_by_author_simple"))

          PostDestroyer.destroy_stubs

          expect(post.reload).to be_present
        end
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.set_data(
            user,
            narrative.get_data(user).merge(tutorial_recover: { post_id: "1" }),
          )

          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.recover.not_found",
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            parent_category = Fabricate(:category, name: "a")
            _category = Fabricate(:category, parent_category: parent_category, name: "b")

            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.category_hashtag.instructions",
                category: "#a:b",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
          end
        end
      end

      context "when user recovers a post in a different topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          PostDestroyer.new(user, other_post).destroy
          PostDestroyer.new(user, other_post).recover

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
        end
      end

      context "when user recovers a post in the right topic" do
        it "should create the right reply" do
          parent_category = Fabricate(:category, name: "a")
          _category = Fabricate(:category, parent_category: parent_category, name: "b")
          post

          PostDestroyer.new(user, post).destroy

          expect { PostDestroyer.new(user, post).recover }.to change { Post.count }.by(1)

          expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.recover.reply", base_uri: "", deletion_after: SiteSetting.delete_removed_posts_after)}

          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.category_hashtag.instructions", category: "#a:b", base_uri: "")}
          RAW

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
          expect(Post.last.raw).to eq(expected_raw.chomp)
        end
      end
    end

    context "with category hashtag tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_category_hashtag,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      context "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
        end
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.category_hashtag.not_found",
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(
              :tutorial_change_topic_notification_level,
            )
          end
        end
      end

      it "should create the right reply" do
        category = Fabricate(:category)

        post.update!(raw: "Check out this ##{category.slug}")
        narrative.input(:reply, user, post: post)

        expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.category_hashtag.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.instructions", base_uri: "")}
          RAW

        expect(Post.last.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(
          :tutorial_change_topic_notification_level,
        )
      end
    end

    context "with topic notification level tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_change_topic_notification_level,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      context "when notification level is changed for another topic" do
        it "should not do anything" do
          other_topic
          user
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect do
            TopicUser.change(
              user.id,
              other_topic.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )
          end.to_not change { Post.count }

          expect(narrative.get_data(user)[:state].to_sym).to eq(
            :tutorial_change_topic_notification_level,
          )
        end
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.not_found",
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(
            :tutorial_change_topic_notification_level,
          )
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.poll.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
          end
        end
      end

      context "when user changed the topic notification level" do
        it "should create the right reply" do
          TopicUser.change(
            user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.poll.instructions", base_uri: "")}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end
      end

      context "when user cannot create polls" do
        it "should create the right reply (polls disabled)" do
          SiteSetting.poll_enabled = false

          TopicUser.change(
            user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.details.instructions", base_uri: "")}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end

        it "should create the right reply (insufficient trust level)" do
          user.update(trust_level: 0)

          TopicUser.change(
            user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking],
          )

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.advanced_user_narrative.details.instructions", base_uri: "")}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end
      end
    end

    context "with poll tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_poll,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      it "allows new users to create polls" do
        user.update(trust_level: 0)

        post = PostCreator.create(user, topic_id: topic.id, raw: <<~RAW)
          [poll type=regular]
          * foo
          * bar
          [/poll]
        RAW

        expect(post.errors[:base].size).to eq(0)
      end

      context "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.advanced_user_narrative.poll.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.advanced_user_narrative.details.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
          end
        end
      end

      it "should create the right reply" do
        post.update!(raw: "[poll]\n* 1\n* 2\n[/poll]\n")
        narrative.input(:reply, user, post: post)

        expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.poll.reply", base_uri: "")}

          #{I18n.t("discourse_narrative_bot.advanced_user_narrative.details.instructions", base_uri: "")}
        RAW

        expect(Post.last.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
      end
    end

    context "with details tutorial" do
      before do
        narrative.set_data(
          user,
          state: :tutorial_details,
          topic_id: topic.id,
          track: described_class.to_s,
        )
      end

      context "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end
      end

      context "when user replies to the topic" do
        it "should create the right reply" do
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.advanced_user_narrative.details.not_found",
              base_uri: "",
            ),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end

        context "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)

            expect do
              DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select
            end.to change { Post.count }.by(1)

            expect(narrative.get_data(user)[:state].to_sym).to eq(:end)
          end
        end
      end

      it "should create the right reply and issue the discobot certificate" do
        post.update!(raw: "[details=\"This is a test\"]\nwooohoo\n[/details]")
        narrative.input(:reply, user, post: post)

        expect(topic.ordered_posts.last(2).first.raw).to eq(
          I18n.t("discourse_narrative_bot.advanced_user_narrative.details.reply", base_uri: ""),
        )

        expect(narrative.get_data(user)).to eq(
          "state" => "end",
          "topic_id" => topic.id,
          "track" => described_class.to_s,
        )

        expect(
          user.badges.where(name: DiscourseNarrativeBot::AdvancedUserNarrative.badge_name).exists?,
        ).to eq(true)

        expect(topic.ordered_posts.last.cooked).to include("<iframe")
        expect(Nokogiri.HTML5(topic.ordered_posts.last.cooked).at("iframe").text).not_to include(
          "Bye for now",
        )
        expect(topic.ordered_posts.last.cooked).to include("</iframe>")
      end
    end
  end

  it "invites to advanced training when user is promoted to TL2" do
    recipient = Fabricate(:user)
    expect {
      DiscourseEvent.trigger(
        :system_message_sent,
        post: Post.last,
        message_type: "tl2_promotion_message",
        recipient: recipient,
      )
    }.to change { Topic.count }
    expect(Topic.last.title).to eq(
      I18n.t("discourse_narrative_bot.tl2_promotion_message.subject_template"),
    )
    expect(Topic.last.topic_users.map(&:user_id).sort).to eq(
      [DiscourseNarrativeBot::Base.new.discobot_user.id, recipient.id],
    )
  end

  it "invites the site_contact_username to advanced training fine as well" do
    recipient = Post.last.user
    SiteSetting.site_contact_username = recipient.username
    expect {
      DiscourseEvent.trigger(
        :system_message_sent,
        post: Post.last,
        message_type: "tl2_promotion_message",
        recipient: recipient,
      )
    }.to change { Topic.count }
    expect(Topic.last.title).to eq(
      I18n.t("discourse_narrative_bot.tl2_promotion_message.subject_template"),
    )
    expect(Topic.last.topic_users.map(&:user_id).sort).to eq(
      [DiscourseNarrativeBot::Base.new.discobot_user.id, recipient.id],
    )
  end

  it "invites to advanced training using the user's effective locale" do
    SiteSetting.allow_user_locale = true
    recipient = Fabricate(:user, locale: "de")

    TranslationOverride.upsert!(
      "de",
      "discourse_narrative_bot.tl2_promotion_message.subject_template",
      "german title",
    )
    TranslationOverride.upsert!(
      "de",
      "discourse_narrative_bot.tl2_promotion_message.text_body_template",
      "german body",
    )

    expect {
      DiscourseEvent.trigger(
        :system_message_sent,
        post: Post.last,
        message_type: "tl2_promotion_message",
        recipient: recipient,
      )
    }.to change { Topic.count }

    topic = Topic.last
    expect(topic.title).to eq("german title")
    expect(topic.first_post.raw).to eq("german body")
  end

  it "invites the correct user when users in site_contact_group_name are invited to the system message" do
    recipient = Fabricate(:user)
    group = Fabricate(:group)
    group.add(Fabricate(:user))
    SiteSetting.site_contact_group_name = "#{group.name}"

    SystemMessage.new(recipient).create("tl2_promotion_message", {})

    expect(Topic.last.topic_users.map(&:user_id).sort).to eq(
      [DiscourseNarrativeBot::Base.new.discobot_user.id, recipient.id],
    )
  end
end
