# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::EntryPoint do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summary_gists_enabled = true
  end

  fab!(:user)

  describe "#inject_into" do
    describe "hot topics gist summarization" do
      fab!(:topic_ai_gist) { Fabricate(:topic_ai_gist, locale: SiteSetting.default_locale) }

      before { TopicHotScore.create!(topic_id: topic_ai_gist.target_id, score: 1.0) }

      let(:topic_query) { TopicQuery.new(user) }

      describe "topic_query_create_list_topics modifier" do
        context "when hot topic summarization is enabled" do
          it "doesn't duplicate records when there more than one summary type" do
            Fabricate(:ai_summary, target: topic_ai_gist.target)

            expect(topic_query.list_hot.topics.map(&:id)).to contain_exactly(
              topic_ai_gist.target_id,
            )
          end

          it "doesn't exclude records when the topic has a single different summary" do
            regular_summary_2 = Fabricate(:ai_summary)
            TopicHotScore.create!(topic_id: regular_summary_2.target_id, score: 1.0)

            expect(topic_query.list_hot.topics.map(&:id)).to contain_exactly(
              regular_summary_2.target_id,
              topic_ai_gist.target_id,
            )
          end

          it "doesn't filter out hot topics without summaries" do
            TopicHotScore.create!(topic_id: Fabricate(:topic).id, score: 1.0)

            expect(topic_query.list_hot.topics.size).to eq(2)
          end
        end
      end

      describe "topic_list_item serializer's ai_summary" do
        context "when hot topic summarization is disabled" do
          before { SiteSetting.ai_summary_gists_enabled = false }
          it "doesn't include summaries" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(gist_topic, scope: Guardian.new, root: false).as_json

            expect(serialized.has_key?(:ai_topic_gist)).to eq(false)
          end
        end

        context "when hot topics summarization is enabled" do
          fab!(:group)

          before do
            group.add(user)
            assign_agent_to(:ai_summary_gists_agent, [group.id])
            SiteSetting.ai_summary_gists_enabled = true
          end

          it "includes the summary" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_present
          end

          it "selects the localized gist and respects the show-original preference" do
            topic_ai_gist.target.update!(locale: "en")
            english_gist =
              topic_ai_gist.tap { |gist| gist.update!(summarized_text: "English gist") }
            japanese_gist =
              Fabricate(
                :topic_ai_gist,
                target: topic_ai_gist.target,
                locale: "ja",
                summarized_text: "日本語の要約",
              )
            SiteSetting.content_localization_enabled = true
            SiteSetting.content_localization_supported_locales = "ja"
            I18n.locale = :ja

            gist_topic =
              topic_query.list_hot.topics.find { |topic| topic.id == topic_ai_gist.target_id }
            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to eq(japanese_gist.summarized_text)

            user.user_option.update!(show_original_content: true)
            original_serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(original_serialized[:ai_topic_gist]).to eq(english_gist.summarized_text)
          end

          it "doesn't include the summary when the user is not a member of the opt-in group" do
            non_member_user = Fabricate(:user)

            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(non_member_user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_nil
          end

          it "works when the topic has whispers" do
            SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
            admin = Fabricate(:admin)
            group.add(admin)
            # We are testing a scenario where AR could get confused if we don't use `references`.

            first = create_post(raw: "this is the first post", title: "super amazing title")

            _whisper =
              create_post(
                topic_id: first.topic.id,
                post_type: Post.types[:whisper],
                raw: "this is a whispered reply",
              )

            Fabricate(:topic_ai_gist, target: first.topic, locale: SiteSetting.default_locale)
            topic_id = first.topic.id
            TopicUser.update_last_read(admin, topic_id, first.post_number, 1, 1)
            TopicUser.change(
              admin.id,
              topic_id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            gist_topic = TopicQuery.new(admin).list_unread.topics.find { |t| t.id == topic_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(admin),
                root: false,
                filter: :unread,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_present
          end

          it "doesn't include the summary if it's not a gist" do
            regular_summary_2 = Fabricate(:ai_summary)
            TopicHotScore.create!(topic_id: regular_summary_2.target_id, score: 1.0)

            hot_topic = topic_query.list_hot.topics.find { |t| t.id == regular_summary_2.target_id }

            serialized =
              TopicListItemSerializer.new(
                hot_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_nil
          end

          it "includes gists in suggested topics with TopicListItemSerializer" do
            main_topic = Fabricate(:topic)
            gist_topic = topic_ai_gist.target

            suggested_list = topic_query.list_suggested_for(main_topic)
            suggested_topic = suggested_list.topics.find { |t| t.id == gist_topic.id }

            skip "suggested topic not found in results" if suggested_topic.nil?

            # Verify that ai_gist_summaries association is preloaded
            expect(suggested_topic.association(:ai_gist_summaries).loaded?).to eq(true)

            serialized =
              TopicListItemSerializer.new(
                suggested_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :suggested,
              ).as_json

            expect(serialized[:ai_topic_gist]).to eq(topic_ai_gist.summarized_text)
          end

          it "includes gists in suggested topics with SuggestedTopicSerializer" do
            main_topic = Fabricate(:topic)
            gist_topic = topic_ai_gist.target

            suggested_list = topic_query.list_suggested_for(main_topic)
            suggested_topic = suggested_list.topics.find { |t| t.id == gist_topic.id }

            skip "suggested topic not found in results" if suggested_topic.nil?

            # Verify that ai_gist_summaries association is preloaded
            expect(suggested_topic.association(:ai_gist_summaries).loaded?).to eq(true)

            serialized =
              SuggestedTopicSerializer.new(
                suggested_topic,
                scope: Guardian.new(user),
                root: false,
              ).as_json

            expect(serialized[:ai_topic_gist]).to eq(topic_ai_gist.summarized_text)
          end
        end
      end
    end

    describe "topic view summary serialization" do
      fab!(:topic) { Fabricate(:topic, locale: "en") }
      fab!(:post) { Fabricate(:post, topic: topic) }

      def serialize_topic_view(topic, user)
        topic_view = TopicView.new(topic.id, user)
        TopicViewSerializer.new(topic_view, scope: user.guardian, root: false).as_json
      end

      it "reports a cached summary only when its locale matches the displayed language" do
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_supported_locales = "he"
        Fabricate(:ai_summary, target: topic, locale: "en")

        english_only = I18n.with_locale(:he) { serialize_topic_view(topic, user) }
        expect(english_only[:has_cached_summary]).to eq(false)

        Fabricate(:ai_summary, target: topic, locale: "he")
        localized = I18n.with_locale(:he) { serialize_topic_view(topic, user) }
        expect(localized[:has_cached_summary]).to eq(true)
      end
    end

    describe "post_created event" do
      fab!(:post)

      it "does not enqueue a job for an up-to-date gist" do
        Fabricate(
          :topic_ai_gist,
          target: post.topic,
          locale: SiteSetting.default_locale,
          highest_target_number: post.topic.highest_post_number,
          created_at: 10.minutes.ago,
        )

        DiscourseEvent.trigger(:post_created, post, {}, post.user)

        expect(Jobs::FastTrackTopicGist.jobs).to be_empty
      end

      it "uses the created post number when the in-memory topic is stale" do
        stale_target_number = post.post_number - 1
        Fabricate(
          :topic_ai_gist,
          target: post.topic,
          locale: SiteSetting.default_locale,
          highest_target_number: stale_target_number,
          created_at: 10.minutes.ago,
        )
        post.topic.highest_post_number = stale_target_number

        expect_enqueued_with(
          job: :fast_track_topic_gist,
          args: {
            topic_id: post.topic.id,
            locale: SiteSetting.default_locale,
            force_regenerate: false,
          },
        ) { DiscourseEvent.trigger(:post_created, post, {}, post.user) }
      end

      it "does not enqueue a job for a recently generated gist" do
        Fabricate(
          :topic_ai_gist,
          target: post.topic,
          locale: SiteSetting.default_locale,
          highest_target_number: 0,
          created_at: 2.minutes.ago,
        )

        DiscourseEvent.trigger(:post_created, post, {}, post.user)

        expect(Jobs::FastTrackTopicGist.jobs).to be_empty
      end

      it "enqueues an outdated gist after the throttle period" do
        Fabricate(
          :topic_ai_gist,
          target: post.topic,
          locale: SiteSetting.default_locale,
          highest_target_number: 0,
          created_at: 10.minutes.ago,
        )

        expect_enqueued_with(
          job: :fast_track_topic_gist,
          args: {
            topic_id: post.topic.id,
            locale: SiteSetting.default_locale,
            force_regenerate: false,
          },
        ) { DiscourseEvent.trigger(:post_created, post, {}, post.user) }
      end
    end

    describe "posts_moved event" do
      fab!(:original_topic, :topic)
      fab!(:destination_topic, :topic)

      context "when backfill is enabled" do
        before { SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 10 }

        it "resets highest_target_number on summaries for both topics" do
          original_summary =
            Fabricate(:ai_summary, target: original_topic, highest_target_number: 5)
          destination_summary =
            Fabricate(:ai_summary, target: destination_topic, highest_target_number: 3)

          DiscourseEvent.trigger(
            :posts_moved,
            original_topic_id: original_topic.id,
            destination_topic_id: destination_topic.id,
          )

          expect(original_summary.reload.highest_target_number).to eq(0)
          expect(destination_summary.reload.highest_target_number).to eq(0)
        end

        it "enqueues fast_track_topic_gist jobs for both topics when gists are enabled" do
          expect_enqueued_with(
            job: :fast_track_topic_gist,
            args: {
              topic_id: original_topic.id,
              locale: SiteSetting.default_locale,
              force_regenerate: true,
            },
          ) do
            expect_enqueued_with(
              job: :fast_track_topic_gist,
              args: {
                topic_id: destination_topic.id,
                locale: SiteSetting.default_locale,
                force_regenerate: true,
              },
            ) do
              DiscourseEvent.trigger(
                :posts_moved,
                original_topic_id: original_topic.id,
                destination_topic_id: destination_topic.id,
              )
            end
          end
        end

        it "does not enqueue gist jobs when gists are disabled" do
          SiteSetting.ai_summary_gists_enabled = false

          DiscourseEvent.trigger(
            :posts_moved,
            original_topic_id: original_topic.id,
            destination_topic_id: destination_topic.id,
          )

          expect(Jobs::FastTrackTopicGist.jobs.size).to eq(0)
        end
      end

      context "when backfill is disabled" do
        before { SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 0 }

        it "does not reset summaries" do
          original_summary =
            Fabricate(:ai_summary, target: original_topic, highest_target_number: 5)

          DiscourseEvent.trigger(
            :posts_moved,
            original_topic_id: original_topic.id,
            destination_topic_id: destination_topic.id,
          )

          expect(original_summary.reload.highest_target_number).to eq(5)
        end

        it "does not enqueue gist jobs" do
          DiscourseEvent.trigger(
            :posts_moved,
            original_topic_id: original_topic.id,
            destination_topic_id: destination_topic.id,
          )

          expect(Jobs::FastTrackTopicGist.jobs.size).to eq(0)
        end
      end
    end
  end
end
