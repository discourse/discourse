# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::NewUserNarrative do
  fab!(:welcome_topic) { Fabricate(:topic, title: "Welcome to Discourse") }
  fab!(:narrative_bot) { ::DiscourseNarrativeBot::Base.new }
  fab!(:discobot_user) { narrative_bot.discobot_user }
  fab!(:discobot_username) { narrative_bot.discobot_username }
  fab!(:first_post) { Fabricate(:post, user: discobot_user) }
  fab!(:user)

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
  fab!(:profile_page_url) { "#{Discourse.base_url}/users/#{user.username}" }
  fab!(:skip_trigger) { DiscourseNarrativeBot::TrackSelector.skip_trigger }
  fab!(:reset_trigger) { DiscourseNarrativeBot::TrackSelector.reset_trigger }

  before do
    stub_image_size
    Jobs.run_immediately!
    SiteSetting.discourse_narrative_bot_enabled = true
    Group.refresh_automatic_groups!
  end

  describe "#notify_timeout" do
    before do
      narrative.set_data(user, state: :tutorial_images, topic_id: topic.id, last_post_id: post.id)
    end

    it "should create the right message" do
      NotificationEmailer.enable
      NotificationEmailer.expects(:process_notification).once

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
            "discourse_narrative_bot.new_user_narrative.hello.message",
            username: user.username,
            title: SiteSetting.title,
            base_uri: "",
          )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.instructions", profile_page_url: profile_page_url, base_uri: "")}
        RAW

        new_post = Post.last

        expect(narrative.get_data(user)).to eq(
          "topic_id" => topic.id,
          "state" => "tutorial_bookmark",
          "last_post_id" => new_post.id,
          "track" => described_class.to_s,
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
            "discourse_narrative_bot.new_user_narrative.hello.message",
            username: user.username,
            title: SiteSetting.title,
            base_uri: "",
          )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.instructions", profile_page_url: profile_page_url, base_uri: "")}
        RAW

        new_post = Post.last

        expect(narrative.get_data(user)).to eq(
          "topic_id" => new_post.topic.id,
          "state" => "tutorial_bookmark",
          "last_post_id" => new_post.id,
          "track" => described_class.to_s,
        )

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(new_post.topic.id).to_not eq(topic.id)
      end
    end
  end

  describe "#input" do
    before do
      SiteSetting.title = "This is an awesome site!"
      narrative.set_data(user, state: :begin)
    end

    describe "when an error occurs" do
      before { narrative.set_data(user, state: :tutorial_flag, topic_id: topic.id) }

      it "should revert to the previous state" do
        narrative
          .expects(:send)
          .with("init_tutorial_search")
          .raises(StandardError.new("some error"))
        narrative.expects(:send).with(:reply_to_flag).returns(post)

        expect { narrative.input(:flag, user, post: post) }.to raise_error(
          StandardError,
          "some error",
        )
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
      end
    end

    describe "when input does not have a valid transition from current state" do
      before { narrative.set_data(user, state: :begin) }

      it "should raise the right error" do
        expect(narrative.input(:something, user, post: post)).to eq(nil)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:begin)
      end
    end

    describe "when [:begin, :init]" do
      it "should create the right post" do
        narrative.expects(:enqueue_timeout_job).never

        narrative.input(:init, user, post: nil)
        new_post = Post.last

        expected_raw =
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.hello.message",
            username: user.username,
            title: SiteSetting.title,
            base_uri: "",
          )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.instructions", profile_page_url: profile_page_url, base_uri: "")}
        RAW

        expect(new_post.raw).to eq(expected_raw.chomp)

        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_bookmark)
      end
    end

    describe "bookmark tutorial" do
      before { narrative.set_data(user, state: :tutorial_bookmark, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post.update!(user_id: -2)
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:bookmark, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_bookmark)
        end
      end

      describe "when bookmark is not on bot's post" do
        it "should not do anything" do
          narrative.expects(:enqueue_timeout_job).with(user).never
          post

          expect { narrative.input(:bookmark, user, post: post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_bookmark)
        end
      end

      describe "when user replies to the topic" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_bookmark)
        end

        describe "when rate_limit_new_user_create_post site setting is disabled" do
          before { SiteSetting.rate_limit_new_user_create_post = 0 }

          it "should create the right reply" do
            narrative.input(:reply, user, post: post)
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.not_found", base_uri: ""),
            )
          end
        end

        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: "@#{discobot_username} #{skip_trigger.upcase}")
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.onebox.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_onebox)
          end
        end
      end

      it "adds an after commit model callback to bookmark" do
        Jobs.run_later!
        bookmark = Fabricate(:bookmark, bookmarkable: Fabricate(:post))
        expect_job_enqueued(
          job: :bot_input,
          args: {
            user_id: bookmark.user_id,
            post_id: bookmark.bookmarkable_id,
            input: "bookmark",
          },
        )
        bookmark2 = Fabricate(:bookmark, bookmarkable: Fabricate(:topic))
        expect_not_enqueued_with(
          job: :bot_input,
          args: {
            user_id: bookmark.user_id,
            post_id: kind_of(Integer),
            input: "bookmark",
          },
        )
      end

      it "triggers the response when bookmarking the topic" do
        Jobs.run_later!
        topic = Fabricate(:topic)
        post = Fabricate(:post, topic: topic)
        bookmark = Fabricate(:bookmark, bookmarkable: topic)

        expect_job_enqueued(
          job: :bot_input,
          args: {
            user_id: bookmark.user_id,
            post_id: post.id,
            input: "bookmark",
          },
        )
      end

      context "when the bookmark is created" do
        let(:profile_page_url) { "#{Discourse.base_url_no_prefix}/prefix/u/#{user.username}" }
        let(:new_post) { Post.last }
        let(:user_state) { narrative.get_data(user)[:state].to_sym }
        let(:expected_raw) { <<~RAW }
          #{I18n.t("discourse_narrative_bot.new_user_narrative.bookmark.reply", bookmark_url: "#{profile_page_url}/activity/bookmarks", base_uri: "")}

          #{I18n.t("discourse_narrative_bot.new_user_narrative.onebox.instructions", base_uri: "")}
        RAW

        before do
          set_subfolder("/prefix")
          post.update!(user: discobot_user)
          narrative.stubs(:enqueue_timeout_job).with(user)
        end

        it "creates the right reply" do
          narrative.input(:bookmark, user, post: post)
          expect(new_post.raw).to eq(expected_raw.chomp)
          expect(user_state).to eq(:tutorial_onebox)
        end
      end

      it "should skip tutorials in SiteSetting.discourse_narrative_bot_skip_tutorials" do
        SiteSetting.discourse_narrative_bot_skip_tutorials = "tutorial_onebox"

        post.update!(raw: "@#{discobot_username} #{skip_trigger.upcase}")

        DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_emoji)
      end
    end

    describe "onebox tutorial" do
      before do
        Oneboxer
          .stubs(:cached_onebox)
          .with("https://en.wikipedia.org/wiki/ROT13")
          .returns("oneboxed Wikipedia")
        narrative.set_data(user, state: :tutorial_onebox, topic_id: topic.id)
      end

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_onebox)
        end
      end

      describe "when post does not contain onebox" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.onebox.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_onebox)
        end
      end

      describe "when user has not liked bot's post" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.onebox.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_onebox)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger.upcase)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t("discourse_narrative_bot.new_user_narrative.emoji.instructions", base_uri: ""),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_emoji)
          end
        end

        describe "when emoji is disabled" do
          before { SiteSetting.enable_emoji = false }

          it "should create the right reply" do
            post.update!(raw: "https://en.wikipedia.org/wiki/ROT13")

            narrative.input(:reply, user, post: post)
            new_post = Post.last

            expected_raw = <<~RAW
              #{I18n.t("discourse_narrative_bot.new_user_narrative.onebox.reply", base_uri: "")}

              #{
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.mention.instructions",
                discobot_username: discobot_username,
                base_uri: "",
              )
            }
            RAW

            expect(new_post.raw).to eq(expected_raw.chomp)
            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_mention)
          end
        end

        it "should create the right reply" do
          post.update!(raw: "https://en.wikipedia.org/wiki/ROT13")

          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.new_user_narrative.onebox.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.new_user_narrative.emoji.instructions", base_uri: "")}
          RAW

          expect(new_post.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_emoji)
        end
      end
    end

    describe "images tutorial" do
      let(:post_2) { Fabricate(:post, topic: topic) }

      before do
        narrative.set_data(
          user,
          state: :tutorial_images,
          topic_id: topic.id,
          last_post_id: post_2.id,
          track: described_class.to_s,
        )
      end

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_images)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.flag.instructions",
                guidelines_url: Discourse.base_url + "/guidelines",
                about_url: Discourse.base_url + "/about",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
          end

          describe "when allow_flagging_staff is false" do
            it "should go to the right state" do
              SiteSetting.allow_flagging_staff = false
              post.update!(raw: skip_trigger)

              DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

              expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
            end
          end
        end
      end

      context "when image is not found" do
        it "should create the right replies" do
          PostActionCreator.like(user, post_2)

          described_class.any_instance.expects(:enqueue_timeout_job).with(user)
          DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

          expect(Post.last.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.images.not_found",
              image_url:
                "#{Discourse.base_url}/plugins/discourse-narrative-bot/images/dog-walk.gif",
              base_uri: "",
            ),
          )

          described_class.any_instance.expects(:enqueue_timeout_job).with(user)

          url = "https://i.ytimg.com/vi/tntOCGkgt98/maxresdefault.jpg"

          stub_request(:head, url).to_return(
            status: 200,
            body: file_from_fixtures("smallest.png").read,
          )

          new_post = Fabricate(:post, user: user, topic: topic, raw: url)

          CookedPostProcessor.new(new_post).post_process
          DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: new_post.id).select

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.new_user_narrative.images.reply", base_uri: "")}

            #{
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.flag.instructions",
              guidelines_url: "#{Discourse.base_url}/guidelines",
              about_url: "#{Discourse.base_url}/about",
              base_uri: "",
            )
          }
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)

          post_action = PostAction.last

          expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
          expect(post_action.user).to eq(discobot_user)
          expect(post_action.post).to eq(new_post)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end
      end

      it "should create the right replies" do
        described_class.any_instance.expects(:enqueue_timeout_job).with(user)
        DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

        expect(Post.last.raw).to eq(
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.images.not_found",
            image_url: "#{Discourse.base_url}/plugins/discourse-narrative-bot/images/dog-walk.gif",
            base_uri: "",
          ),
        )

        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_images)

        new_post =
          Fabricate(
            :post,
            user: user,
            topic: topic,
            raw: "<img src='https://i.ytimg.com/vi/tntOCGkgt98/maxresdefault.jpg'>",
          )

        described_class.any_instance.expects(:enqueue_timeout_job).with(user)
        DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: new_post.id).select

        expect(Post.last.raw).to eq(
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.images.like_not_found",
            url: post_2.url,
            base_uri: "",
          ),
        )

        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_images)

        expect(narrative.get_data(user)[:tutorial_images][:post_id]).to eq(new_post.id)

        described_class.any_instance.expects(:enqueue_timeout_job).with(user)
        PostActionCreator.like(user, post_2)

        expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.new_user_narrative.images.reply")}

          #{
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.flag.instructions",
            guidelines_url: "#{Discourse.base_url}/guidelines",
            about_url: "#{Discourse.base_url}/about",
            base_uri: "",
          )
        }
        RAW

        expect(Post.last.raw).to eq(expected_raw.chomp)

        post_action = PostAction.last

        expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
        expect(post_action.user).to eq(discobot_user)
        expect(post_action.post).to eq(new_post)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
      end
    end

    describe "likes tutorial" do
      let(:post_2) { Fabricate(:post, topic: topic) }

      before do
        narrative.set_data(
          user,
          state: :tutorial_likes,
          topic_id: topic.id,
          last_post_id: post_2.id,
          track: described_class.to_s,
        )
      end

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_likes)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.flag.instructions",
                guidelines_url: Discourse.base_url + "/guidelines",
                about_url: Discourse.base_url + "/about",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
          end

          describe "when allow_flagging_staff is false" do
            it "should go to the right state" do
              SiteSetting.allow_flagging_staff = false
              post.update!(raw: skip_trigger)

              DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

              expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
            end
          end
        end

        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.likes.not_found",
              url: post_2.url,
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_likes)
        end
      end

      describe "when the post is liked" do
        it "should create the right reply" do
          PostActionCreator.like(user, post_2)

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.new_user_narrative.likes.reply")}

            #{
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.flag.instructions",
              guidelines_url: "#{Discourse.base_url}/guidelines",
              about_url: "#{Discourse.base_url}/about",
              base_uri: "",
            )
          }
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end
      end
    end

    describe "formatting tutorial" do
      before { narrative.set_data(user, state: :tutorial_formatting, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_formatting)
        end
      end

      describe "when post does not contain any formatting" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.formatting.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_formatting)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.quoting.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_quote)
          end
        end
      end

      ["**bold**", "__italic__", "[b]bold[/b]", "[i]italic[/i]"].each do |raw|
        it "should create the right reply" do
          post.update!(raw: raw)

          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.new_user_narrative.formatting.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.new_user_narrative.quoting.instructions", base_uri: "")}
          RAW

          expect(new_post.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_quote)
        end
      end
    end

    describe "quote tutorial" do
      before { narrative.set_data(user, state: :tutorial_quote, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_quote)
        end
      end

      describe "when post does not contain any quotes" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.quoting.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_quote)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.images.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_images)
          end

          it "should use correct path to images on subfolder installs" do
            GlobalSetting.stubs(:relative_url_root).returns("/forum")
            Discourse.stubs(:base_path).returns("/forum")

            post.update!(raw: skip_trigger)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to include("/forum/plugins/discourse-narrative-bot/images")
          end
        end

        describe "when embedded_media_post_allowed_groups does not include the user" do
          before do
            SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
            Group.refresh_automatic_groups!
          end

          it "should skip the images tutorial step" do
            post.update!(
              raw:
                "[quote=\"#{post.user}, post:#{post.post_number}, topic:#{topic.id}\"]\n:monkey: :fries:\n[/quote]",
            )

            narrative.expects(:enqueue_timeout_job).with(user)
            narrative.input(:reply, user, post: post)

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_likes)
          end
        end

        it "should create the right reply" do
          post.update!(
            raw:
              "[quote=\"#{post.user}, post:#{post.post_number}, topic:#{topic.id}\"]\n:monkey: :fries:\n[/quote]",
          )

          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expected_raw = <<~RAW
            #{I18n.t("discourse_narrative_bot.new_user_narrative.quoting.reply", base_uri: "")}

            #{I18n.t("discourse_narrative_bot.new_user_narrative.images.instructions", base_uri: "")}
          RAW

          expect(new_post.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_images)
        end
      end
    end

    describe "emoji tutorial" do
      before { narrative.set_data(user, state: :tutorial_emoji, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_emoji)
        end
      end

      describe "when post does not contain any emoji" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.emoji.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_emoji)
        end
      end

      describe "when user replies to the topic" do
        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.mention.instructions",
                discobot_username: discobot_username,
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_mention)
          end
        end
      end

      describe "when user mentions is disabled" do
        before { SiteSetting.enable_mentions = false }

        it "should skip the mention tutorial step" do
          post.update!(raw: ":monkey: :fries:")

          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_formatting)
        end
      end

      it "should create the right reply" do
        post.update!(raw: ":monkey: :fries:")

        narrative.expects(:enqueue_timeout_job).with(user)
        narrative.input(:reply, user, post: post)
        new_post = Post.last

        expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.new_user_narrative.emoji.reply", base_uri: "")}

          #{
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.mention.instructions",
            discobot_username: discobot_username,
            base_uri: "",
          )
        }
        RAW

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_mention)
      end
    end

    describe "mention tutorial" do
      before { narrative.set_data(user, state: :tutorial_mention, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_mention)
        end
      end

      describe "when post does not contain any mentions" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.mention.not_found",
              username: user.username,
              discobot_username: discobot_username,
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_mention)
        end
      end

      describe "when reply contains the skip trigger" do
        it "should create the right reply" do
          post.update!(raw: skip_trigger)
          described_class.any_instance.expects(:enqueue_timeout_job).with(user)

          DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.formatting.instructions",
              discobot_username: discobot_username,
              base_uri: "",
            ),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_formatting)
        end
      end

      it "should create the right reply" do
        post.update!(raw: "@disCoBot hello how are you doing today?")

        narrative.expects(:enqueue_timeout_job).with(user)
        narrative.input(:reply, user, post: post)
        new_post = Post.last

        expected_raw = <<~RAW
          #{I18n.t("discourse_narrative_bot.new_user_narrative.mention.reply", base_uri: "")}

          #{
          I18n.t("discourse_narrative_bot.new_user_narrative.formatting.instructions", base_uri: "")
        }
        RAW

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_formatting)
      end
    end

    describe "flag tutorial" do
      let(:post) { Fabricate(:post, user: discobot_user, topic: topic) }
      let(:another_post) { Fabricate(:post, user: discobot_user, topic: topic) }
      let(:flag) do
        Fabricate(
          :flag_post_action,
          post: post,
          user: user,
          post_action_type_id: PostActionType.types[:inappropriate],
        )
      end
      let(:other_flag) do
        Fabricate(
          :flag_post_action,
          post: another_post,
          user: user,
          post_action_type_id: PostActionType.types[:spam],
        )
      end
      let(:other_post) { Fabricate(:post, user: user, topic: topic) }

      before do
        flag
        narrative.set_data(user, state: :tutorial_flag, topic_id: topic.id)
      end

      describe "when post flagged is not for the right topic" do
        it "should not do anything" do
          narrative.expects(:enqueue_timeout_job).with(user).never
          flag.update!(post: other_post)

          expect { narrative.input(:flag, user, post: flag.post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end
      end

      describe "when post is flagged incorrectly" do
        it "should create the right reply and stay on the same step" do
          narrative.expects(:enqueue_timeout_job).with(user).never
          other_flag.update!(post: another_post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.flag.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end
      end

      describe "when post being flagged does not belong to discobot " do
        it "should not do anything" do
          narrative.expects(:enqueue_timeout_job).with(user).never
          flag.update!(post: other_post)

          expect { narrative.input(:flag, user, post: flag.post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end
      end

      describe "when user replies to the topic" do
        it "should create the right reply" do
          narrative.input(:reply, user, post: other_post)
          new_post = Post.last

          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.flag.not_found", base_uri: ""),
          )
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_flag)
        end

        describe "when reply contains the skip trigger" do
          it "should create the right reply" do
            other_post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: other_post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.new_user_narrative.search.instructions",
                base_uri: "",
              ),
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
          end
        end
      end

      it "should create the right reply" do
        narrative.expects(:enqueue_timeout_job).with(user)

        expect { narrative.input(:flag, user, post: flag.post) }.to change { PostAction.count }.by(
          -1,
        )

        new_post = Post.last

        expected_raw = <<~RAW
          #{
          I18n.t(
            "discourse_narrative_bot.new_user_narrative.flag.reply",
            base_uri: "",
            group_url: Group.find(Group::AUTO_GROUPS[:staff]).full_url,
          )
        }

          #{I18n.t("discourse_narrative_bot.new_user_narrative.search.instructions", base_uri: "")}
        RAW

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
      end
    end

    describe "search tutorial" do
      before { narrative.set_data(user, state: :tutorial_search, topic_id: topic.id) }

      describe "when post is not in the right topic" do
        it "should not do anything" do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
        end
      end

      describe "when post does not contain the right answer" do
        it "should create the right reply" do
          narrative.expects(:enqueue_timeout_job).with(user)
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(
            I18n.t("discourse_narrative_bot.new_user_narrative.search.not_found", base_uri: ""),
          )

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)
        end
      end

      describe "when post contain the right answer" do
        let(:post) { Fabricate(:post, user: discobot_user, topic: topic) }
        let(:flag) { Fabricate(:flag_post_action, post: post, user: user) }

        before do
          narrative.set_data(user, state: :tutorial_flag, topic_id: topic.id)

          DiscourseNarrativeBot::TrackSelector.new(:flag, user, post_id: flag.post_id).select

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_search)

          expect(post.reload.topic.first_post.raw).to include(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.search.hidden_message",
              base_uri: "",
              search_answer: described_class.search_answer,
            ),
          )
        end

        it "should clean up if the tutorial is skipped" do
          post.update!(raw: skip_trigger)

          expect do
            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select
          end.to change { Post.count }.by(1)

          expect(first_post.reload.raw).to eq("Hello world")
          expect(narrative.get_data(user)[:state].to_sym).to eq(:end)
        end

        it "should create the right reply" do
          post.update!(raw: "#{described_class.search_answer} this is a capybara")

          expect do
            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select
          end.to change { Post.count }.by(2)

          new_post = topic.ordered_posts.last(2).first

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.search.reply",
              search_url: "#{Discourse.base_url}/search",
              base_uri: "",
            ).chomp,
          )

          expect(first_post.reload.raw).to eq("Hello world")

          expect(narrative.get_data(user)).to include(
            "state" => "end",
            "topic_id" => new_post.topic_id,
            "track" => described_class.to_s,
          )

          expect(
            user.badges.where(name: DiscourseNarrativeBot::NewUserNarrative.badge_name).exists?,
          ).to eq(true)
        end

        it "should accept a raw emoji" do
          post.update!(
            raw: "#{described_class.search_answer_emoji} this is the emoji you mentioned",
          )

          expect do
            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select
          end.to change { Post.count }.by(2)

          new_post = topic.ordered_posts.last(2).first

          expect(new_post.raw).to eq(
            I18n.t(
              "discourse_narrative_bot.new_user_narrative.search.reply",
              search_url: "#{Discourse.base_url}/search",
              base_uri: "",
            ).chomp,
          )
        end
      end
    end
  end
end
