# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::TrackSelector do
  let(:user) { Fabricate(:user) }
  let(:narrative_bot) { DiscourseNarrativeBot::Base.new }
  let(:discobot_user) { narrative_bot.discobot_user }
  let(:discobot_username) { narrative_bot.discobot_username }
  let(:narrative) { DiscourseNarrativeBot::NewUserNarrative.new }

  let(:random_mention_reply) do
    I18n.t(
      "discourse_narrative_bot.track_selector.random_mention.reply",
      discobot_username: discobot_username,
      help_trigger: described_class.help_trigger,
    )
  end

  before do
    stub_image_size
    stub_request(
      :get,
      "http://api.forismatic.com/api/1.0/?format=json&lang=en&method=getQuote",
    ).to_return(
      status: 200,
      body: "{\"quoteText\":\"Be Like Water\",\"quoteAuthor\":\"Bruce Lee\"}",
    )

    SiteSetting.discourse_narrative_bot_enabled = true
  end

  let(:help_message) do
    end_message = <<~RAW
    #{
      I18n.t(
        "discourse_narrative_bot.track_selector.random_mention.tracks",
        discobot_username: discobot_username,
        reset_trigger: described_class.reset_trigger,
        tracks:
          "#{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}, #{DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger}",
      )
    }

    #{
      I18n.t(
        "discourse_narrative_bot.track_selector.random_mention.bot_actions",
        discobot_username: discobot_username,
        dice_trigger: described_class.dice_trigger,
        quote_trigger: described_class.quote_trigger,
        quote_sample:
          DiscourseNarrativeBot::QuoteGenerator.format_quote("Be Like Water", "Bruce Lee"),
        magic_8_ball_trigger: described_class.magic_8_ball_trigger,
      )
    }
    RAW

    end_message.chomp
  end

  before { Jobs.run_immediately! }

  describe "#select" do
    context "when in a PM with discobot" do
      let(:first_post) { Fabricate(:post, user: discobot_user) }

      let(:topic) do
        Fabricate(
          :private_message_topic,
          first_post: first_post,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: discobot_user),
            Fabricate.build(:topic_allowed_user, user: user),
          ],
        )
      end

      let(:post) { Fabricate(:post, topic: topic, user: user) }

      context "while in a tutorial track" do
        before do
          narrative.set_data(
            user,
            state: :tutorial_formatting,
            topic_id: topic.id,
            track: "DiscourseNarrativeBot::NewUserNarrative",
          )
        end

        context "when bot is mentioned" do
          it "should select the right track" do
            post.update!(raw: "@discobot show me what you can do")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t("discourse_narrative_bot.new_user_narrative.formatting.not_found"),
            )
          end
        end

        context "when bot is replied to" do
          it "should select the right track" do
            post.update!(
              raw: "show me what you can do",
              reply_to_post_number: first_post.post_number,
            )

            described_class.new(:reply, user, post_id: post.id).select

            expect(Post.last.raw).to eq(
              I18n.t("discourse_narrative_bot.new_user_narrative.formatting.not_found"),
            )

            described_class.new(:reply, user, post_id: post.id).select

            expected_raw = <<~RAW
            #{
              I18n.t(
                "discourse_narrative_bot.track_selector.do_not_understand.first_response",
                reset_trigger:
                  "#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
              )
            }

            #{
              I18n.t(
                "discourse_narrative_bot.track_selector.do_not_understand.track_response",
                reset_trigger:
                  "#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
                skip_trigger: described_class.skip_trigger,
              )
            }
            RAW

            expect(Post.last.raw).to eq(expected_raw.chomp)
          end

          it "should not enqueue any user email" do
            NotificationEmailer.enable
            user.user_option.update!(email_level: UserOption.email_level_types[:always])

            post.update!(
              raw: "show me what you can do",
              reply_to_post_number: first_post.post_number,
            )

            NotificationEmailer.expects(:process_notification).never

            described_class.new(:reply, user, post_id: post.id).select

            expect(Post.last.raw).to eq(
              I18n.t("discourse_narrative_bot.new_user_narrative.formatting.not_found"),
            )
          end
        end

        context "when a non regular post is created" do
          it "should not do anything" do
            moderator_post = Fabricate(:moderator_post, user: user, topic: topic)

            expect do
              described_class.new(:reply, user, post_id: moderator_post.id).select
            end.to_not change { Post.count }
          end
        end

        context "when user thank the bot" do
          it "should like the post" do
            post.update!(raw: "thanks!")

            expect { described_class.new(:reply, user, post_id: post.id).select }.to change {
              PostAction.count
            }.by(1)

            post_action = PostAction.last

            expect(post_action.post).to eq(post)
            expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
            expect(Post.last).to eq(post)

            expect(DiscourseNarrativeBot::NewUserNarrative.new.get_data(user)["state"]).to eq(nil)
          end
        end

        context "when reply contains a reset trigger" do
          it "should reset the track" do
            post.update!(
              raw:
                "#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
            )

            described_class.new(:reply, user, post_id: post.id).select

            expect(DiscourseNarrativeBot::NewUserNarrative.new.get_data(user)["state"]).to eq(
              "tutorial_bookmark",
            )
          end

          context "when reset trigger in surrounded by quotes" do
            it "should reset the track" do
              post.update!(
                raw:
                  "'#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}'",
              )

              described_class.new(:reply, user, post_id: post.id).select

              expect(DiscourseNarrativeBot::NewUserNarrative.new.get_data(user)["state"]).to eq(
                "tutorial_bookmark",
              )
            end
          end

          context "when reset trigger in a middle of a sentence" do
            context "when post is less than reset trigger exact match limit" do
              it "should reset the track" do
                post.update!(
                  raw:
                    "I would like to #{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger} now",
                )

                described_class.new(:reply, user, post_id: post.id).select

                expect(DiscourseNarrativeBot::NewUserNarrative.new.get_data(user)["state"]).to eq(
                  "tutorial_bookmark",
                )
              end
            end

            context "when post exceeds reset trigger exact match limit" do
              it "should not reset the track" do
                post.update!(
                  raw:
                    "I would like to #{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger} now #{"a" * described_class::RESET_TRIGGER_EXACT_MATCH_LENGTH}",
                )

                expect { described_class.new(:reply, user, post_id: post.id).select }.to change {
                  Post.count
                }.by(1)

                expect(DiscourseNarrativeBot::NewUserNarrative.new.get_data(user)["state"]).to eq(
                  "tutorial_formatting",
                )
              end
            end
          end
        end

        context "when a new user is added into the topic" do
          before { topic.allowed_users << Fabricate(:user) }

          it "should stop the new user track" do
            post

            expect { described_class.new(:reply, user, post_id: post.id).select }.to_not change {
              Post.count
            }
          end
        end
      end

      context "when at the end of a tutorial track" do
        before do
          narrative.set_data(
            user,
            state: :end,
            topic_id: topic.id,
            track: "DiscourseNarrativeBot::NewUserNarrative",
          )
        end

        context "with generic replies" do
          after do
            Discourse.redis.del("#{described_class::GENERIC_REPLIES_COUNT_PREFIX}#{user.id}")
          end

          it "should create the right generic do not understand responses" do
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.track_selector.do_not_understand.first_response",
                reset_trigger:
                  "#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
              ),
            )

            described_class.new(
              :reply,
              user,
              post_id:
                Fabricate(
                  :post,
                  topic: new_post.topic,
                  user: user,
                  reply_to_post_number: new_post.post_number,
                ).id,
            ).select

            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.track_selector.do_not_understand.second_response",
                base_path: Discourse.base_path,
                reset_trigger:
                  "#{described_class.reset_trigger} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
              ),
            )

            new_post =
              Fabricate(
                :post,
                topic: new_post.topic,
                user: user,
                reply_to_post_number: new_post.post_number,
              )

            expect {
              described_class.new(:reply, user, post_id: new_post.id).select
            }.to_not change { Post.count }
          end
        end

        context "when discobot is mentioned at the end of a track" do
          it "should create the right reply" do
            post.update!(raw: "Show me what you can do @discobot")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(random_mention_reply)
          end

          context "when asking discobot for help" do
            it "should create the right reply" do
              post.update!(raw: "show me what you can do @discobot display help")
              described_class.new(:reply, user, post_id: post.id).select

              expect(Post.last.raw).to include(help_message)
            end

            context "as an admin or moderator" do
              it "should include the commands to start the advanced user track" do
                user.update!(moderator: true)
                post.update!(raw: "Show me what you can do @discobot display help")
                described_class.new(:reply, user, post_id: post.id).select
                new_post = Post.last

                expect(new_post.raw).to include(
                  DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger,
                )
              end
            end

            context "as a user that has completed the new user track" do
              it "should include the commands to start the advanced user track" do
                narrative.set_data(
                  user,
                  state: :end,
                  topic_id: post.topic.id,
                  track: "DiscourseNarrativeBot::NewUserNarrative",
                )

                BadgeGranter.grant(
                  Badge.find_by(name: DiscourseNarrativeBot::NewUserNarrative.badge_name),
                  user,
                )

                post.update!(raw: "Show me what you can do @discobot display help")
                described_class.new(:reply, user, post_id: post.id).select
                new_post = Post.last

                expect(new_post.raw).to include(
                  DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger,
                )
              end
            end
          end

          context "when discobot is asked to roll dice" do
            before { narrative.set_data(user, state: :end, topic_id: topic.id) }

            it "should create the right reply" do
              post.update!(raw: "roll 2d1")
              described_class.new(:reply, user, post_id: post.id).select
              new_post = Post.last

              expect(new_post.raw).to eq(
                I18n.t("discourse_narrative_bot.dice.results", results: "1, 1"),
              )
            end

            context "when range of dice request is too high" do
              before { srand(1) }

              it "should create the right reply" do
                stub_request(
                  :get,
                  "https://www.wired.com/2016/05/mathematical-challenge-of-designing-the-worlds-most-complex-120-sided-dice",
                ).to_return(status: 200, body: "", headers: {})

                post.update!(
                  raw: "roll 1d#{DiscourseNarrativeBot::Dice::MAXIMUM_RANGE_OF_DICE + 1}",
                )
                described_class.new(:reply, user, post_id: post.id).select
                new_post = Post.last

                expected_raw = <<~RAW
                #{I18n.t("discourse_narrative_bot.dice.out_of_range")}

                #{I18n.t("discourse_narrative_bot.dice.results", results: "38")}
                RAW

                expect(new_post.raw).to eq(expected_raw.chomp)
              end
            end

            context "when number of dice to roll is too high" do
              it "should create the right reply" do
                post.update!(raw: "roll #{DiscourseNarrativeBot::Dice::MAXIMUM_NUM_OF_DICE + 1}d1")
                described_class.new(:reply, user, post_id: post.id).select
                new_post = Post.last

                expected_raw = <<~RAW
                #{I18n.t("discourse_narrative_bot.dice.not_enough_dice", count: DiscourseNarrativeBot::Dice::MAXIMUM_NUM_OF_DICE)}

                #{I18n.t("discourse_narrative_bot.dice.results", results: "1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1")}
                RAW

                expect(new_post.raw).to eq(expected_raw.chomp)
              end
            end

            context "when dice combination is invalid" do
              it "should create the right reply" do
                post.update!(raw: "roll 0d1")
                described_class.new(:reply, user, post_id: post.id).select

                expect(Post.last.raw).to eq(I18n.t("discourse_narrative_bot.dice.invalid"))
              end
            end
          end
        end
      end

      context "when in a normal PM with discobot" do
        context "when discobot is replied to" do
          it "should create the right reply" do
            SiteSetting.discourse_narrative_bot_disable_public_replies = true
            post.update!(raw: "Show me what you can do @discobot")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(random_mention_reply)
          end

          it "works with french locale" do
            I18n.with_locale("fr") do
              post.update!(raw: "@discobot afficher l'aide")
              described_class.new(:reply, user, post_id: post.id).select
              # gsub'ing to ensure non-breaking whitespaces matches regular whitespaces
              expect(Post.last.raw.gsub(/[[:space:]]+/, " ")).to eq(
                help_message.gsub(/[[:space:]]+/, " "),
              )
            end
          end

          it "should not rate limit help message" do
            post.update!(raw: "@discobot")
            other_post = Fabricate(:post, raw: "discobot", topic: post.topic)

            [post, other_post].each do |reply|
              described_class.new(:reply, user, post_id: reply.id).select
              expect(Post.last.raw).to eq(random_mention_reply)
            end
          end
        end
      end
    end

    context "with random discobot mentions" do
      let(:topic) { Fabricate(:topic) }
      let(:post) { Fabricate(:post, topic: topic, user: user) }

      context "when discobot public replies are disabled" do
        before { SiteSetting.discourse_narrative_bot_disable_public_replies = true }

        context "when discobot is mentioned" do
          it "should not reply" do
            post.update!(raw: "Show me what you can do @discobot")

            expect do described_class.new(:reply, user, post_id: post.id).select end.to_not change {
              Post.count
            }
          end
        end
      end

      context "when discobot is mentioned" do
        it "should create the right reply" do
          post.update!(raw: "Show me what you can do @discobot")
          described_class.new(:reply, user, post_id: post.id).select
          new_post = Post.last
          expect(new_post.raw).to eq(random_mention_reply)
        end

        it "tells the user to enable the onboarding tips first" do
          user.user_option.update!(skip_new_user_tips: true)
          post.update!(raw: "Show me what you can do @discobot")

          described_class.new(:reply, user, post_id: post.id).select

          new_post = Post.last
          expect(new_post.raw).to eq(
            I18n.t("discourse_narrative_bot.track_selector.random_mention.discobot_disabled"),
          )
        end

        it "should be case insensitive towards discobot's username" do
          discobot_user.update!(username: "DisCoBot")

          post.update!(raw: "Show me what you can do @discobot")
          described_class.new(:reply, user, post_id: post.id).select
          new_post = Post.last
          expect(new_post.raw).to eq(random_mention_reply)
        end

        it "should not like the public post" do
          post.update!(raw: "thanks @discobot!")

          expect { described_class.new(:reply, user, post_id: post.id).select }.not_to change {
            PostAction.count
          }

          new_post = Post.last
          expect(new_post.raw).to eq(random_mention_reply)
        end

        context "with rate limiting random reply message in public topic" do
          let(:topic) { Fabricate(:topic) }
          let(:other_post) { Fabricate(:post, raw: "@discobot show me something", topic: topic) }
          let(:post) { Fabricate(:post, topic: topic) }

          after { Discourse.redis.flushdb }

          context "when random reply massage has been displayed in the last 6 hours" do
            it "should not do anything" do
              Discourse.redis.set(
                "#{described_class::PUBLIC_DISPLAY_BOT_HELP_KEY}:#{other_post.topic_id}",
                post.post_number - 11,
              )

              Discourse.redis.class.any_instance.expects(:ttl).returns(19.hours.to_i)

              user
              post.update!(raw: "Show me what you can do @discobot")

              expect { described_class.new(:reply, user, post_id: post.id).select }.to_not change {
                Post.count
              }
            end
          end

          context "when random reply message has not been displayed in the last 6 hours" do
            it "should create the right reply" do
              Discourse.redis.set(
                "#{described_class::PUBLIC_DISPLAY_BOT_HELP_KEY}:#{other_post.topic_id}",
                post.post_number - 11,
              )

              Discourse.redis.class.any_instance.expects(:ttl).returns(7.hours.to_i)

              user
              post.update!(raw: "Show me what you can do @discobot")

              described_class.new(:reply, user, post_id: post.id).select

              expect(Post.last.raw).to eq(random_mention_reply)
            end
          end

          context "when random reply message has been displayed in the last 10 replies" do
            it "should not do anything" do
              described_class.new(:reply, user, post_id: other_post.id).select
              expect(Post.last.raw).to eq(random_mention_reply)

              expect(
                Discourse
                  .redis
                  .get("#{described_class::PUBLIC_DISPLAY_BOT_HELP_KEY}:#{other_post.topic_id}")
                  .to_i,
              ).to eq(other_post.post_number.to_i)

              user
              post.update!(raw: "Show me what you can do @discobot")

              expect do
                described_class.new(:reply, user, post_id: post.id).select
              end.to_not change { Post.count }
            end
          end
        end

        context "when asking discobot for help" do
          it "should create the right reply" do
            post.update!(raw: "@discobot display help")
            described_class.new(:reply, user, post_id: post.id).select

            expect(Post.last.raw).to eq(help_message)
          end
        end

        context "when asking discobot to start new user track" do
          context "with invalid text" do
            it "should not trigger the bot" do
              post.update!(
                raw:
                  "`@discobot #{I18n.t("discourse_narrative_bot.track_selector.reset_trigger")} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}`",
              )

              expect { described_class.new(:reply, user, post_id: post.id).select }.to_not change {
                Post.count
              }
            end
          end
        end

        context "when discobot is asked to roll dice" do
          it "should create the right reply" do
            post.update!(raw: "@discobot roll 2d1")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t("discourse_narrative_bot.dice.results", results: "1, 1"),
            )
          end

          it "should ignore extra whitespace proceeding the mention" do
            post.update!(raw: "@discobot   roll 2d1")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t("discourse_narrative_bot.dice.results", results: "1, 1"),
            )
          end

          context "when dice roll is requested incorrectly" do
            it "should create the right reply" do
              post.update!(raw: "roll 2d1 @discobot")
              described_class.new(:reply, user, post_id: post.id).select

              expect(Post.last.raw).to eq(random_mention_reply)
            end
          end

          context "when roll dice command is present inside a quote" do
            it "should ignore the command" do
              user
              post.update!(raw: "[quote=\"Donkey, post:6, topic:1\"]\n@discobot roll 2d1\n[/quote]")

              expect { described_class.new(:reply, user, post_id: post.id).select }.to_not change {
                Post.count
              }
            end
          end
        end

        context "when a quote is requested" do
          it "should create the right reply" do
            post.update!(raw: "@discobot quote")
            described_class.new(:reply, user, post_id: post.id).select
            new_post = Post.last

            expect(new_post.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.quote.results",
                quote: "Be Like Water",
                author: "Bruce Lee",
              ),
            )
          end

          context "when quote is requested incorrectly" do
            it "should create the right reply" do
              post.update!(raw: "quote @discobot")
              described_class.new(:reply, user, post_id: post.id).select

              expect(Post.last.raw).to eq(random_mention_reply)
            end
          end

          context "when quote command is present inside a onebox or quote" do
            it "should ignore the command" do
              user
              post.update!(raw: "[quote=\"Donkey, post:6, topic:1\"]\n@discobot quote\n[/quote]")

              expect { described_class.new(:reply, user, post_id: post.id).select }.to_not change {
                Post.count
              }
            end
          end

          context "when user requesting quote has a preferred locale" do
            before do
              SiteSetting.allow_user_locale = true
              user.update!(locale: "it")
              srand(1)
            end

            it "should create the right reply" do
              post.update!(raw: "@discobot quote")
              described_class.new(:reply, user, post_id: post.id).select
              key = "discourse_narrative_bot.quote.6"

              expect(Post.last.raw).to eq(
                I18n.t(
                  "discourse_narrative_bot.quote.results",
                  quote: I18n.t("#{key}.quote"),
                  author: I18n.t("#{key}.author"),
                ),
              )
            end
          end
        end

        context "when magic 8 ball is requested" do
          before { srand(1) }

          it "should create the right reply" do
            post.update!(raw: "@discobot fortune")
            described_class.new(:reply, user, post_id: post.id).select

            expect(Post.last.raw).to eq(
              I18n.t(
                "discourse_narrative_bot.magic_8_ball.result",
                result: I18n.t("discourse_narrative_bot.magic_8_ball.answers.6"),
              ),
            )
          end
        end

        context "when bot is asked to reset/start a track" do
          context "when user likes a post containing a reset trigger" do
            it "should not start the track" do
              another_post =
                Fabricate(
                  :post,
                  user: Fabricate(:user),
                  topic: topic,
                  raw:
                    "@discobot #{I18n.t("discourse_narrative_bot.track_selector.reset_trigger")} #{DiscourseNarrativeBot::NewUserNarrative.reset_trigger}",
                )

              user

              expect do PostActionCreator.like(user, another_post) end.to_not change { Post.count }
            end
          end

          context "when new and advanced user triggers overlap" do
            before do
              @overrides = []

              @overrides << TranslationOverride.upsert!(
                I18n.locale,
                "discourse_narrative_bot.new_user_narrative.reset_trigger",
                "tutorial",
              )

              @overrides << TranslationOverride.upsert!(
                I18n.locale,
                "discourse_narrative_bot.advanced_user_narrative.reset_trigger",
                "tutorial advanced",
              )
            end

            after { @overrides.each(&:destroy!) }

            it "should start the right track" do
              post.update!(
                raw:
                  "@discobot #{I18n.t("discourse_narrative_bot.track_selector.reset_trigger")} #{DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger}",
              )

              expect do described_class.new(:reply, user, post_id: post.id).select end.to change {
                Post.count
              }.by(2)
            end
          end
        end
      end
    end

    context "when sending pm to self" do
      let(:other_topic) do
        topic_allowed_user = Fabricate.build(:topic_allowed_user, user: user)
        Fabricate(:private_message_topic, topic_allowed_users: [topic_allowed_user])
      end

      let(:other_post) { Fabricate(:post, topic: other_topic) }

      context "when a new message is made" do
        it "should not do anything" do
          other_post

          expect {
            described_class.new(:reply, user, post_id: other_post.id).select
          }.to_not change { Post.count }
        end
      end
    end

    context "when sending pms to bot" do
      let(:other_topic) do
        topic_allowed_user = Fabricate.build(:topic_allowed_user, user: user)
        bot = Fabricate.build(:topic_allowed_user, user: discobot_user)
        Fabricate(:private_message_topic, topic_allowed_users: [topic_allowed_user, bot])
      end

      let(:other_post) { Fabricate(:post, topic: other_topic) }

      context "when a new like is made" do
        it "should not do anything" do
          other_post
          expect { described_class.new(:like, user, post_id: other_post.id).select }.to_not change {
            Post.count
          }
        end
      end

      context "when a new message is made" do
        it "should create the right reply" do
          described_class.new(:reply, user, post_id: other_post.id).select

          expect(Post.last.raw).to eq(random_mention_reply)
        end
      end

      context "when user thanks the bot" do
        it "should like the post" do
          other_post.update!(raw: "thanks!")

          expect { described_class.new(:reply, user, post_id: other_post.id).select }.to change {
            PostAction.count
          }.by(1)

          post_action = PostAction.last

          expect(post_action.post).to eq(other_post)
          expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
        end
      end
    end
  end
end
