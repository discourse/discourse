# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:user) { Fabricate(:user, username: "username") }
  fab!(:admin)
  fab!(:group)

  describe "#option_info" do
    let(:options) { TopicsFilter.option_info(Guardian.new) }
    it "should return a correct hash with name and description keys for all" do
      expect(options).to be_an(Array)
      expect(options).to all(be_a(Hash))
      expect(options).to all(include(:name, :description))

      # 10 is arbitray, but better than just checking for 1
      expect(options.length).to be > 10
    end

    it "should include nothing about tags when disabled" do
      SiteSetting.tagging_enabled = false

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).to be_nil

      SiteSetting.tagging_enabled = true
      options = TopicsFilter.option_info(Guardian.new)

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).not_to be_nil
    end

    it "should not include user-specific options for anonymous users" do
      anon_options = TopicsFilter.option_info(Guardian.new)
      logged_in_options = TopicsFilter.option_info(user.guardian)

      anon_option_names = anon_options.map { |o| o[:name] }.to_set
      logged_in_option_names = logged_in_options.map { |o| o[:name] }.to_set

      user_specific_options = %w[
        in:
        in:pinned
        in:bookmarked
        in:watching
        in:tracking
        in:muted
        in:normal
        in:watching_first_post
        in:unseen
      ]

      user_specific_options.each { |option| expect(anon_option_names).not_to include(option) }
      user_specific_options.each { |option| expect(logged_in_option_names).to include(option) }
    end

    it "should apply the topics_filter_options modifier for authenticated users" do
      plugin_instance = Plugin::Instance.new
      DiscoursePluginRegistry.register_modifier(
        plugin_instance,
        :topics_filter_options,
      ) do |results, guardian|
        if guardian.authenticated?
          results << {
            name: "custom-filter:",
            description: "A custom filter option from modifier",
            type: "text",
          }
        end
        results
      end

      anon_options = TopicsFilter.option_info(Guardian.new)
      logged_in_options = TopicsFilter.option_info(Guardian.new(user))

      anon_option_names = anon_options.map { |o| o[:name] }
      logged_in_option_names = logged_in_options.map { |o| o[:name] }

      expect(anon_option_names).not_to include("custom-filter:")
      expect(logged_in_option_names).to include("custom-filter:")

      custom_option = logged_in_options.find { |o| o[:name] == "custom-filter:" }
      expect(custom_option).to include(
        name: "custom-filter:",
        description: "A custom filter option from modifier",
        type: "text",
      )
    ensure
      DiscoursePluginRegistry.reset_register!(:modifiers)
    end
  end

  describe "#filter_from_query_string" do
    describe "when filtering with the `users` and `group` filters" do
      fab!(:u1) { Fabricate(:user, username: "alice") }
      fab!(:u2) { Fabricate(:user, username: "bob") }
      fab!(:u3) { Fabricate(:user, username: "cara") }
      fab!(:g1) { Fabricate(:group, name: "group1") }
      fab!(:g2) { Fabricate(:group, name: "group2") }

      before do
        g1.add(u1)
        g2.add(u2)
      end

      fab!(:topic_by_u1) { Fabricate(:topic).tap { |t| Fabricate(:post, topic: t, user: u1) } }
      fab!(:topic_by_u2) { Fabricate(:topic).tap { |t| Fabricate(:post, topic: t, user: u2) } }
      fab!(:topic_by_u1_and_u2) do
        Fabricate(:topic).tap do |t|
          Fabricate(:post, topic: t, user: u1)
          Fabricate(:post, topic: t, user: u2)
        end
      end

      it "users:alice returns topics where alice participated" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("users:alice")
            .pluck(:id)
        expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
        expect(ids).not_to include(topic_by_u2.id)
      end

      it "users:alice,bob returns topics with either alice or bob" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("users:alice,bob")
            .pluck(:id)
        expect(ids).to include(topic_by_u1.id, topic_by_u2.id, topic_by_u1_and_u2.id)
      end

      it "users:alice+bob returns only topics where both participated/allowed" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("users:alice+bob")
            .pluck(:id)
        expect(ids).to contain_exactly(topic_by_u1_and_u2.id)
      end

      it "-users:alice,bob returns topics where neither alice nor bob participated" do
        post = Fabricate(:post)
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-users:alice,bob")
            .pluck(:id)
        expect(ids).to contain_exactly(post.topic_id)
      end

      it "-users:alice+bob returns topics where bob and alice did not participate together" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-users:alice+bob")
            .pluck(:id)
        expect(ids).to contain_exactly(topic_by_u1.id, topic_by_u2.id)
      end

      it "-user:alice,bob (alias) returns topics where neither alice nor bob participated" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-user:alice,bob")
            .pluck(:id)
        expect(ids).to contain_exactly()
      end

      it "group:group1 returns topics with participants from the group or group-allowed PMs" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("group:group1")
            .pluck(:id)
        expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
      end

      it "groups:group1,group2 returns union of both groups" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("groups:group1,group2")
            .pluck(:id)
        expect(ids).to include(topic_by_u1.id, topic_by_u2.id, topic_by_u1_and_u2.id)
      end

      it "group:group1+group2 returns only topics with both groups represented" do
        ids =
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("group:group1+group2")
            .pluck(:id)
        expect(ids).to contain_exactly(topic_by_u1_and_u2.id)
      end

      context "with whispers" do
        fab!(:whisperer_group, :group)
        fab!(:whisperer_user) { Fabricate(:user).tap { |u| whisperer_group.add(u) } }
        fab!(:regular_user, :user)
        fab!(:topic_with_whisper_only) do
          Fabricate(:post, user: u1, post_type: Post.types[:whisper]).topic
        end

        before { SiteSetting.whispers_allowed_groups = "#{whisperer_group.id}" }

        it "users:alice should not return topics where alice only whispered when viewed by non-whisperer" do
          ids =
            TopicsFilter
              .new(guardian: Guardian.new(regular_user))
              .filter_from_query_string("users:alice")
              .pluck(:id)
          expect(ids).not_to include(topic_with_whisper_only.id)
          expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
        end

        it "group:group1 should not return topics where group members only whispered when viewed by non-whisperer" do
          ids =
            TopicsFilter
              .new(guardian: Guardian.new(regular_user))
              .filter_from_query_string("group:group1")
              .pluck(:id)
          expect(ids).not_to include(topic_with_whisper_only.id)
          expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
        end
      end
    end

    describe "ordering by hot score" do
      fab!(:t1, :topic)
      fab!(:t2, :topic)

      before do
        TopicHotScore.create!(topic_id: t1.id, score: 2.0)
        TopicHotScore.create!(topic_id: t2.id, score: 3.0)
      end

      it "order:hot sorts by topic_hot_scores.score desc" do
        expect(
          TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("order:hot").pluck(:id),
        ).to start_with(t2.id, t1.id)
      end

      it "order:hot-asc sorts ascending" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("order:hot-asc")
            .pluck(:id),
        ).to start_with(t1.id, t2.id)
      end
    end
    describe "when filtering with multiple filters" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:closed_topic_with_tag) { Fabricate(:topic, tags: [tag], closed: true) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:closed_topic_with_tag2) { Fabricate(:topic, tags: [tag2], closed: true) }

      it "should return the right topics when query string is `status:closed tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:closed tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(closed_topic_with_tag.id, closed_topic_with_tag2.id)
      end
    end

    describe "when filtering with the `in` filter" do
      fab!(:topic)

      fab!(:pinned_topic) do
        Fabricate(:topic, pinned_at: Time.zone.now, pinned_until: 1.hour.from_now)
      end

      fab!(:expired_pinned_topic) do
        Fabricate(:topic, pinned_at: 2.hours.ago, pinned_until: 1.hour.ago)
      end

      describe "when query string is `in:pinned`" do
        it "should return topics that are pinned" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("in:pinned")
              .pluck(:id),
          ).to contain_exactly(pinned_topic.id)
        end

        it "should not return pinned topics that have expired" do
          freeze_time(2.hours.from_now) do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("in:pinned")
                .pluck(:id),
            ).to eq([])
          end
        end
      end

      describe "new / unread operators" do
        fab!(:user_for_new_filters, :user)
        let!(:new_topic) { Fabricate(:topic) }
        let!(:unread_topic) do
          Fabricate(:topic, created_at: 2.days.ago).tap do |t|
            Fabricate(:post, topic: t)
            Fabricate(:post, topic: t)

            TopicUser.update_last_read(user_for_new_filters, t.id, 1, 1, 0)
            TopicUser.change(
              user_for_new_filters.id,
              t.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )
          end
        end
        before { user_for_new_filters.user_option.update!(new_topic_duration_minutes: 1.day.ago) }

        it "in:new-topics returns only new topics" do
          ids =
            TopicsFilter
              .new(guardian: user_for_new_filters.guardian)
              .filter_from_query_string("in:new-topics")
              .pluck(:id)
          expect(ids).to contain_exactly(new_topic.id)
        end

        it "in:new-replies returns only unread (non-new) topics" do
          ids =
            TopicsFilter
              .new(guardian: user_for_new_filters.guardian)
              .filter_from_query_string("in:new-replies")
              .where(id: [new_topic.id, unread_topic.id])
              .pluck(:id)
          expect(ids).to contain_exactly(unread_topic.id)
        end

        it "in:new returns union of new and unread topics" do
          ids =
            TopicsFilter
              .new(guardian: user_for_new_filters.guardian)
              .filter_from_query_string("in:new")
              .where(id: [new_topic.id, unread_topic.id])
              .pluck(:id)
          expect(ids).to contain_exactly(new_topic.id, unread_topic.id)
        end

        it "in:unseen returns only unseen topics" do
          user_for_unseen_filters = user_for_new_filters
          seen_topic = Fabricate(:topic)
          TopicUser.update_last_read(user_for_unseen_filters, seen_topic.id, 1, 1, 0)
          unseen_topic = Fabricate(:topic)
          ids =
            TopicsFilter
              .new(guardian: user_for_unseen_filters.guardian)
              .filter_from_query_string("in:unseen")
              .where(id: [seen_topic.id, unseen_topic.id])
              .pluck(:id)
          expect(ids).to contain_exactly(unseen_topic.id)
        end

        it "anonymous user with in:new returns none" do
          ids =
            TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("in:new").pluck(:id)
          expect(ids).to be_empty
        end
      end

      describe "when query string is `in:bookmarked`" do
        fab!(:bookmark) do
          BookmarkManager.new(user).create_for(
            bookmarkable_id: topic.id,
            bookmarkable_type: "Topic",
          )
        end

        fab!(:bookmark2) do
          BookmarkManager.new(admin).create_for(
            bookmarkable_id: topic.id,
            bookmarkable_type: "Topic",
          )
        end

        it "should not return any topics when user is anonymous" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("in:bookmarked")
              .pluck(:id),
          ).to eq([])
        end

        it "should return topics that are bookmarked" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `in:bookmarked in:pinnned`" do
        it "should return topics that are bookmarked and pinned" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked in:pinned")
              .pluck(:id),
          ).to eq([])

          BookmarkManager.new(user).create_for(
            bookmarkable_id: pinned_topic.id,
            bookmarkable_type: "Topic",
          )

          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked in:pinned")
              .pluck(:id),
          ).to contain_exactly(pinned_topic.id)
        end
      end

      TopicUser.notification_levels.keys.each do |notification_level|
        describe "when query string is `in:#{notification_level}`" do
          fab!("user_#{notification_level}_topic".to_sym) do
            Fabricate(:topic).tap do |topic|
              TopicUser.change(
                user.id,
                topic.id,
                notification_level: TopicUser.notification_levels[notification_level],
              )
            end
          end

          it "should not return any topics if the user is anonymous" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("in:#{notification_level}")
                .pluck(:id),
            ).to eq([])
          end

          it "should return topics that the user has notification level set to #{notification_level}" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:#{notification_level}")
                .pluck(:id),
            ).to contain_exactly(self.public_send("user_#{notification_level}_topic").id)
          end
        end
      end

      describe "when filtering by multiple topic notification levels" do
        fab!(:user_muted_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:muted],
            )
          end
        end

        fab!(:user_watching_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:watching],
            )
          end
        end

        fab!(:user_tracking_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )
          end
        end

        describe "when query string is `in:muted,invalid`" do
          it "should ignore the invalid notification level" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted,invalid")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id)
          end
        end

        describe "when query string is `in:muted in:tracking`" do
          it "should return topics that the user is tracking or has muted" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted in:tracking")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id, user_tracking_topic.id)
          end
        end

        describe "when query string is `in:muted,tracking" do
          it "should return topics that the user is tracking or has muted" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted,tracking")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id, user_tracking_topic.id)
          end
        end
      end

      describe "when query string is `in:watching_first_post`" do
        fab!(:category_watching_first_post, :category)
        fab!(:category_regular, :category)
        fab!(:tag_watching_first_post, :tag)
        fab!(:tag_regular, :tag)

        fab!(:topic_in_watched_category) do
          Fabricate(:topic, category: category_watching_first_post)
        end
        fab!(:topic_in_regular_category) { Fabricate(:topic, category: category_regular) }
        fab!(:topic_with_watched_tag) { Fabricate(:topic, tags: [tag_watching_first_post]) }
        fab!(:topic_with_regular_tag) { Fabricate(:topic, tags: [tag_regular]) }
        fab!(:topic_with_both) do
          Fabricate(:topic, category: category_watching_first_post, tags: [tag_watching_first_post])
        end

        before do
          CategoryUser.set_notification_level_for_category(
            user,
            CategoryUser.notification_levels[:watching_first_post],
            category_watching_first_post.id,
          )
          TagUser.change(
            user.id,
            tag_watching_first_post.id,
            TagUser.notification_levels[:watching_first_post],
          )
        end

        it "should not return any topics if the user is anonymous" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("in:watching_first_post")
              .pluck(:id),
          ).to be_empty
        end

        it "should return the union of topics in watched categories and topics with watched tags" do
          ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:watching_first_post")
              .pluck(:id)

          expect(ids).to contain_exactly(
            topic_in_watched_category.id,
            topic_with_watched_tag.id,
            topic_with_both.id,
          )
        end

        it "should work when combined with other filters" do
          topic_in_watched_category.update!(closed: true)

          ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:watching_first_post status:closed")
              .pluck(:id)

          expect(ids).to contain_exactly(topic_in_watched_category.id)
        end

        it "should work with comma-separated notification levels" do
          user_watching_topic =
            Fabricate(:topic).tap do |topic|
              TopicUser.change(
                user.id,
                topic.id,
                notification_level: TopicUser.notification_levels[:watching],
              )
            end

          ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:watching,watching_first_post")
              .pluck(:id)

          expect(ids).to contain_exactly(
            user_watching_topic.id,
            topic_in_watched_category.id,
            topic_with_watched_tag.id,
            topic_with_both.id,
          )
        end
      end
    end

    describe "when filtering with custom filters" do
      fab!(:topic)
      fab!(:word_count_topic) { Fabricate(:topic, word_count: 42) }
      fab!(:word_count_topic_2) { Fabricate(:topic, word_count: 42) }

      let(:word_count_block) { Proc.new { |scope, value| scope.where(word_count: value) } }
      let(:id_block) { Proc.new { |scope, value| scope.where(id: value) } }
      let(:plugin) { Plugin::Instance.new }

      it "supports a custom filter" do
        plugin.add_filter_custom_filter("word_count", &word_count_block)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("word_count:42")
            .pluck(:id),
        ).to contain_exactly(word_count_topic.id, word_count_topic_2.id)
      ensure
        DiscoursePluginRegistry.reset_register!(:custom_filter_mappings)
      end

      it "supports multiple custom filters" do
        plugin.add_filter_custom_filter("word_count", &word_count_block)
        plugin.add_filter_custom_filter("id", &id_block)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("word_count:42 id:#{word_count_topic.id}")
            .pluck(:id),
        ).to contain_exactly(word_count_topic.id)
      ensure
        DiscoursePluginRegistry.reset_register!(:custom_filter_mappings)
      end
    end

    describe "when filtering by categories" do
      fab!(:category) { Fabricate(:category, name: "category") }

      fab!(:category_subcategory) do
        Fabricate(:category, parent_category: category, name: "category subcategory")
      end

      fab!(:category2) { Fabricate(:category, name: "category2") }

      fab!(:category2_subcategory) do
        Fabricate(:category, parent_category: category2, name: "category2 subcategory")
      end

      fab!(:topic_in_category) { Fabricate(:topic, category: category) }
      fab!(:topic_in_category_subcategory) { Fabricate(:topic, category: category_subcategory) }
      fab!(:topic_in_category2) { Fabricate(:topic, category: category2) }
      fab!(:topic_in_category2_subcategory) { Fabricate(:topic, category: category2_subcategory) }

      describe "when query string is `category:category`" do
        it "should return topics from specified category and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id, topic_in_category_subcategory.id)
        end

        it "should return topics from specified category, its subcategories and sub-subcategories" do
          SiteSetting.max_category_nesting = 3

          category_subcategory_subcategory =
            Fabricate(
              :category,
              parent_category: category_subcategory,
              name: "category subcategory subcategory",
            )

          topic_in_category_subcategory_subcategory =
            Fabricate(:topic, category: category_subcategory_subcategory)

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category_subcategory_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category,category2`" do
        it "should return topics from any of the specified categories and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category,category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category category:category2`" do
        it "should return topics from any of the specified categories and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category category:category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category =category:category2`" do
        it "should return topics and subcategory topics from category but only topics from category2" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category =category:category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
          )
        end
      end

      describe "when query string is `-category:category`" do
        it "should not return any topics from specified category or its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-category:category")
              .pluck(:id),
          ).to contain_exactly(topic_in_category2.id, topic_in_category2_subcategory.id)
        end
      end

      describe "when query string is `-category:category2,category`" do
        it "should not return any topics from either specified categories or their subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-category:category2,category")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `-category:category -category:category2-subcategory`" do
        it "should not return any topics from either specified category or their subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-category:category -category:category2-subcategory")
              .pluck(:id),
          ).to contain_exactly(topic_in_category2.id)
        end
      end

      describe "when query string is `-=category:category`" do
        it "should not return any topics from the specified category only" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-=category:category")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
          )
        end
      end

      describe "when query string is `-=category:category,category2`" do
        it "should not return any topics from the specified categories only" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-=category:category,category2")
              .pluck(:id),
          ).to contain_exactly(topic_in_category_subcategory.id, topic_in_category2_subcategory.id)
        end
      end

      describe "when query string is `=category:category`" do
        it "should not return topics from subcategories`" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("=category:category")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id)
        end
      end

      describe "when query string is `=category:category,category2`" do
        it "should not return topics from subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("=category:category,category2")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id, topic_in_category2.id)
        end
      end

      describe "when query string is `category:category2 -=category:category2-subcategory`" do
        it "should return topics from category2 and its subcategories but not from the category2-subcategory" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "category:category2 -=category:category2:category2-subcategory",
              )
              .pluck(:id),
          ).to contain_exactly(topic_in_category2.id)
        end

        describe "when max category nesting is 3" do
          fab!(:category2_subcategory_subcategory) do
            SiteSetting.max_category_nesting = 3
            Fabricate(:category, parent_category: category2_subcategory, name: "sub-subcategory")
          end

          fab!(:topic_in_category2_subcategory_subcategory) do
            Fabricate(:topic, category: category2_subcategory_subcategory)
          end

          before { SiteSetting.max_category_nesting = 3 }

          it "should return topics from category2, category2's sub-categories and category2's sub-sub-categories but not from the category2-subcategory only" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string(
                  "category:category2 -=category:category2:category2-subcategory",
                )
                .pluck(:id),
            ).to contain_exactly(
              topic_in_category2.id,
              topic_in_category2_subcategory_subcategory.id,
            )
          end
        end
      end

      describe "when `slug_generation_method` site setting is set to encoded" do
        before do
          SiteSetting.slug_generation_method = "encoded"
          category.update!(name: "日本語", slug: "日本語")
        end

        describe "when query string is `category:日本語`" do
          it 'should return topics from category with slug "日本語"' do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:日本語")
                .pluck(:id),
            ).to contain_exactly(topic_in_category.id, topic_in_category_subcategory.id)
          end
        end

        describe "when query string is `category:日本語:안녕하세요`" do
          before { category_subcategory.update!(name: "안녕하세요 ", slug: "안녕하세요 ") }

          it "should return topics from category with slug '안녕하세요'" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:日本語:안녕하세요")
                .pluck(:id),
            ).to contain_exactly(topic_in_category_subcategory.id)
          end
        end
      end

      describe "when multiple categories have subcategories with the same name" do
        fab!(:category_subcategory) do
          Fabricate(:category, parent_category: category, name: "subcategory")
        end

        fab!(:category2_subcategory) do
          Fabricate(:category, parent_category: category2, name: "subcategory")
        end

        fab!(:topic_in_category_subcategory) { Fabricate(:topic, category: category_subcategory) }
        fab!(:topic_in_category2_subcategory) { Fabricate(:topic, category: category2_subcategory) }

        describe "when query string is `category:subcategory`" do
          it "should return topics from subcategories of both categories" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:subcategory")
                .pluck(:id),
            ).to contain_exactly(
              topic_in_category_subcategory.id,
              topic_in_category2_subcategory.id,
            )
          end
        end

        describe "when query string is `category:category:subcategory`" do
          it "should return topics from subcategories of the specified category" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category:subcategory")
                .pluck(:id),
            ).to contain_exactly(topic_in_category_subcategory.id)
          end
        end

        describe "when query string is `category:category2:subcategory`" do
          it "should return topics from subcategories of the specified category" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category2:subcategory")
                .pluck(:id),
            ).to contain_exactly(topic_in_category2_subcategory.id)
          end
        end

        describe "when query string is `category:category:subcategory,category2:subcategory`" do
          it "should return topics from either subcategory" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category:subcategory,category2:subcategory")
                .pluck(:id),
            ).to contain_exactly(
              topic_in_category_subcategory.id,
              topic_in_category2_subcategory.id,
            )
          end
        end

        describe "when max category nesting is 3" do
          fab!(:category_subcategory_subcategory) do
            SiteSetting.max_category_nesting = 3
            Fabricate(:category, parent_category: category_subcategory, name: "sub-subcategory")
          end

          fab!(:category2_subcategory_subcategory) do
            SiteSetting.max_category_nesting = 3
            Fabricate(:category, parent_category: category2_subcategory, name: "sub-subcategory")
          end

          fab!(:topic_in_category_subcategory_subcategory) do
            Fabricate(:topic, category: category_subcategory_subcategory)
          end

          fab!(:topic_in_category2_subcategory_subcategory) do
            Fabricate(:topic, category: category2_subcategory_subcategory)
          end

          before { SiteSetting.max_category_nesting = 3 }

          describe "when query string is `category:category:subcategory:sub-subcategory`" do
            it "return topics from category with slug 'sub-subcategory' with the category ancestor chain of 'subcategory' and 'category'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:category:subcategory:sub-subcategory")
                  .pluck(:id),
              ).to contain_exactly(topic_in_category_subcategory_subcategory.id)
            end
          end

          describe "when query string is `=category:category2:subcategory`" do
            it "return topics from category with slug 'subcategory' with the category ancestor chain of 'category2'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("=category:category2:subcategory")
                  .pluck(:id),
              ).to contain_exactly(topic_in_category2_subcategory.id)
            end
          end

          describe "when query string is `category:category2:subcategory`" do
            it "return topics and subcategories topics from category with slug 'subcategory' with the category ancestor chain of 'category2'" do
              category2_subcategory_subcategory2 =
                Fabricate(
                  :category,
                  parent_category: category2_subcategory,
                  name: "sub-subcategory2",
                )

              topic_in_category2_subcategory_subcategory2 =
                Fabricate(:topic, category: category2_subcategory_subcategory2)

              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:category2:subcategory")
                  .pluck(:id),
              ).to contain_exactly(
                topic_in_category2_subcategory.id,
                topic_in_category2_subcategory_subcategory.id,
                topic_in_category2_subcategory_subcategory2.id,
              )
            end
          end

          describe "when query string is `category:sub-subcategory`" do
            it "return topics from either category with slug 'sub-subcategory'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:sub-subcategory")
                  .pluck(:id),
              ).to contain_exactly(
                topic_in_category_subcategory_subcategory.id,
                topic_in_category2_subcategory_subcategory.id,
              )
            end
          end
        end
      end
    end

    describe "when filtering by status" do
      fab!(:topic)
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:archived_topic) { Fabricate(:topic, archived: true) }
      fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }
      fab!(:foobar_topic) { Fabricate(:topic, closed: true, word_count: 42) }

      after { TopicsFilter.custom_status_filters.clear }

      context "with custom status filters" do
        let(:enabled?) { true }

        before do
          TopicsFilter.add_filter_by_status("foobar", enabled: method(:enabled?)) do |scope|
            scope.where("word_count = 42")
          end
        end

        it "applies the custom filter" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("status:foobar")
              .pluck(:id),
          ).to contain_exactly(foobar_topic.id)
        end

        context "when the filter is disabled" do
          let(:enabled?) { false }

          it "does not apply the custom filter" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("status:foobar")
                .pluck(:id),
            ).to contain_exactly(*Topic.all.pluck(:id))
          end
        end
      end

      it "should only return topics that have not been closed or archived when query string is `status:open`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:open")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that have been deleted when query string is `status:deleted` and user can see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(deleted_topic_id)
      end

      it "should ignore status filter when query string is `status:deleted` and user cannot see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id, foobar_topic.id)
      end

      it "should only return topics that have been archived when query string is `status:archived`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:archived")
            .pluck(:id),
        ).to contain_exactly(archived_topic.id)
      end

      it "should only return topics that are visible when query string is `status:listed`" do
        Topic.update_all(visible: false)
        topic.update!(visible: true)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:listed")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not visible when query string is `status:unlisted`" do
        Topic.update_all(visible: true)
        topic.update!(visible: false)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:unlisted")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not in any read-restricted category when query string is `status:public`" do
        private_category = Fabricate(:private_category, group: group)
        topic_in_private_category = Fabricate(:topic, category: private_category)

        expect(
          TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("").pluck(:id),
        ).to include(topic_in_private_category.id)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:public")
            .pluck(:id),
        ).not_to include(topic_in_private_category.id)
      end

      describe "when query string is `status:closed status:unlisted`" do
        fab!(:closed_and_unlisted_topic) { Fabricate(:topic, closed: true, visible: false) }

        it "should only return topics that have been closed and are not visible" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("status:closed status:unlisted")
              .pluck(:id),
          ).to contain_exactly(closed_and_unlisted_topic.id)
        end
      end
    end

    describe "when filtering by tags" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:tag3) { Fabricate(:tag, name: "tag3") }

      fab!(:group_only_tag) { Fabricate(:tag, name: "group-only-tag") }
      fab!(:group)

      let!(:staff_tag_group) do
        Fabricate(
          :tag_group,
          permissions: {
            group.name => TagGroupPermission.permission_types[:full],
          },
          tag_names: [group_only_tag.name],
        )
      end

      fab!(:topic_without_tag, :topic)
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:topic_with_group_only_tag) { Fabricate(:topic, tags: [group_only_tag]) }

      it "should not filter any topics by tags when tagging is disabled" do
        SiteSetting.tagging_enabled = false

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      describe "when query string is `tag:tag1+tag2`" do
        it "should only return topics that are tagged with all of the specified tags" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("tag:#{tag.name}+#{tag2.name}")
              .pluck(:id),
          ).to contain_exactly(topic_with_tag_and_tag2.id)
        end
      end

      it "should only return topics that are tagged with all of the specified tags when query string is `tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with tag1 and tag2 when query string is `tags:tag1 tags:tag2`" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag_and_tag2_and_tag3.id)
      end

      describe "when query string is `tags:front-end,back-end tags:pri-high,pri-low`" do
        fab!(:front_end) { Fabricate(:tag, name: "front-end") }
        fab!(:back_end) { Fabricate(:tag, name: "back-end") }
        fab!(:pri_high) { Fabricate(:tag, name: "pri-high") }
        fab!(:pri_low) { Fabricate(:tag, name: "pri-low") }

        it "should only return topics that are tagged with front-end+pri-high, front-end+pri-low, back-end+pri-high, back-end+pri-low" do
          topic_with_front_end_pri_high = Fabricate(:topic, tags: [front_end, pri_high])
          topic_with_front_end_pri_low = Fabricate(:topic, tags: [front_end, pri_low])
          topic_with_back_end_pri_high = Fabricate(:topic, tags: [back_end, pri_high])
          topic_with_back_end_pri_low = Fabricate(:topic, tags: [back_end, pri_low])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [front_end, back_end])

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "tags:#{front_end.name},#{back_end.name} tags:#{pri_high.name},#{pri_low.name}",
              )
              .pluck(:id),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_back_end_pri_high.id,
            topic_with_back_end_pri_low.id,
          )
        end

        it "should return topics that are tagged with front-end+back-end+pri-low or front-end+back-end+pri-high" do
          topic_with_front_end_back_end_pri_low =
            Fabricate(:topic, tags: [front_end, back_end, pri_low])
          topic_with_front_end_back_end_pri_high =
            Fabricate(:topic, tags: [front_end, back_end, pri_high])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [front_end, back_end])

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "tags:#{front_end.name},#{back_end.name} tags:#{pri_low.name},#{pri_high.name}",
              )
              .pluck(:id),
          ).to contain_exactly(
            topic_with_front_end_back_end_pri_low.id,
            topic_with_front_end_back_end_pri_high.id,
          )
        end
      end

      describe "when query string is `tags:front-end tags:pri-high,pri-low`" do
        fab!(:front_end) { Fabricate(:tag, name: "front-end") }
        fab!(:pri_high) { Fabricate(:tag, name: "pri-high") }
        fab!(:pri_low) { Fabricate(:tag, name: "pri-low") }

        it "should only return topics tagged with front-end and or pri-high or pri-low" do
          topic_with_front_end_pri_high = Fabricate(:topic, tags: [front_end, pri_high])
          topic_with_front_end_pri_low = Fabricate(:topic, tags: [front_end, pri_low])
          topic_with_front_end_pri_high_pri_low =
            Fabricate(:topic, tags: [front_end, pri_high, pri_low])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [pri_high, pri_low])

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "tags:#{front_end.name} tags:#{pri_high.name},#{pri_low.name}",
              )
              .pluck(:id),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_front_end_pri_high_pri_low.id,
          )

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "tags:#{pri_high.name},#{pri_low.name} tags:#{front_end.name}",
              )
              .pluck(:id),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_front_end_pri_high_pri_low.id,
          )
        end
      end

      describe "when query string is `tags:tag1,tag2,tag3`" do
        it "should only return topics that are tagged with either tag1, tag2 or tag3" do
          topic_with_tag3 = Fabricate(:topic, tags: [tag3])

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("tags:#{tag.name},#{tag2.name},#{tag3.name}")
              .pluck(:id),
          ).to contain_exactly(
            topic_with_tag.id,
            topic_with_tag_and_tag2.id,
            topic_with_tag2.id,
            topic_with_tag3.id,
          )
        end
      end

      describe "when query string is `tags:tag1+tag2+tag3`" do
        it "should only return topics that are tagged with tag1, tag2 and tag3" do
          topic_with_tag_tag2_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("tags:#{tag.name}+#{tag2.name}+#{tag3.name}")
              .pluck(:id),
          ).to contain_exactly(topic_with_tag_tag2_tag3.id)
        end
      end

      it "should only return topics that are tagged with tag1 and tag2 but not tag3 when query string is `tags:tag1 tags:tag2 -tags:tag3`" do
        _topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name} -tags:tag3")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with any of the specified tags when query string is `tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name},#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:tag1+tag2+invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1+tag2+invalid")
            .pluck(:id),
        ).to eq([])
      end

      it "should still filter topics by specificed tags when query string is `tags:tag1,tag2,invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1,tag2,invalid")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:group-only-tag` because specified tag is hidden to user" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to eq([])
      end

      it "should return the right topics when query string is `tags:group-only-tag` and user has access to specified tag" do
        group.add(admin)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to contain_exactly(topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with specified tag when query string is `-tags:tag1`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_tag2.id, topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with all of the specified tags when query string is `-tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1+tag2")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "should only return topics that are not tagged with any of the specified tags when query string is `-tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_group_only_tag.id)
      end

      describe "when query string is tag:日べé1" do
        before { tag.update!(name: "日べé1") }

        it "should return topics that are tagged with the specified tag" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("tag:日べé1")
              .pluck(:id),
          ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id)
        end
      end

      describe "when query string is `tags:tag_name`" do
        before { tag.update!(name: "tag_with_underscore") }
        it "should return topics even when tag contains underscore" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("tags:#{tag.name}")
              .pluck(:id),
          ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id)
        end
      end
    end

    describe "when filtering by tag_groups" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:tag3) { Fabricate(:tag, name: "tag3") }

      fab!(:topic_without_tag, :topic)
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }

      fab!(:tag_group) { Fabricate(:tag_group, tag_names: [tag.name, tag2.name]) }
      fab!(:topic_with_tag3) { Fabricate(:topic, tags: [tag3]) }

      fab!(:staff_only_tag) { Fabricate(:tag, name: "group-only-tag") }
      fab!(:group)
      let!(:staff_tag_group) do
        Fabricate(
          :tag_group,
          permissions: {
            group.name => TagGroupPermission.permission_types[:full],
          },
          name: "staff-only-tag-group",
          tag_names: [staff_only_tag.name],
        )
      end

      fab!(:topic_with_staff_only_tag) { Fabricate(:topic, tags: [staff_only_tag]) }

      it "should only return topics that are tagged with any of the specified tag_group when query string is tag_group:tag_group_name" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tag_group:#{tag_group.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id, topic_with_tag2.id)
      end

      it "should only return topics that are not excluded by the specified tag_group when query string is -tag_group:tag_group_name" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tag_group:#{tag_group.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag3.id, topic_without_tag.id, topic_with_staff_only_tag.id)
      end

      it "should return the right topics when query string is `tag_group:staff_tag_group` and user has access to specified tag" do
        group.add(admin)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("tag_group:#{staff_tag_group.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_staff_only_tag.id)
      end

      it "should not return any topics when query string is `tag_group:staff_tag_group` because specified tag is hidden to user" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tag_group:#{staff_tag_group.name}")
            .pluck(:id),
        ).to eq([])
      end
    end

    describe "when filtering by tag_groups with special characters" do
      fab!(:tag) { Fabricate(:tag, name: "special-tag") }
      fab!(:tag_group_with_spaces) do
        Fabricate(:tag_group, name: "My Tag Group", tag_names: [tag.name])
      end
      fab!(:tag_group_with_ampersand) do
        Fabricate(:tag_group, name: "News & Updates", tag_names: [tag.name])
      end
      fab!(:tag_group_with_parens) do
        Fabricate(:tag_group, name: "Group (Test)", tag_names: [tag.name])
      end
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:topic_without_tag, :topic)

      it "should filter by tag group name with spaces using double quotes" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string('tag_group:"My Tag Group"')
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id)
      end

      it "should filter by tag group name with spaces using single quotes" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tag_group:'My Tag Group'")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id)
      end

      it "should filter by tag group name with ampersand" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string('tag_group:"News & Updates"')
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id)
      end

      it "should filter by tag group name with parentheses" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string('tag_group:"Group (Test)"')
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id)
      end

      it "should perform case-insensitive tag group lookup" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string('tag_group:"MY TAG GROUP"')
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id)
      end

      it "should handle exclude prefix with quoted tag group names" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string('-tag_group:"My Tag Group"')
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id)
      end

      it "should maintain backward compatibility with unquoted tag group names" do
        simple_tag = Fabricate(:tag, name: "simple-tag")
        _simple_group = Fabricate(:tag_group, name: "simple", tag_names: [simple_tag.name])
        topic_simple = Fabricate(:topic, tags: [simple_tag])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tag_group:simple")
            .pluck(:id),
        ).to contain_exactly(topic_simple.id)
      end
    end

    describe "when filtering by locale" do
      fab!(:en_topic) { Fabricate(:topic, locale: "en") }
      fab!(:ja_topic) { Fabricate(:topic, locale: "ja") }
      fab!(:es_topic) { Fabricate(:topic, locale: "es") }
      fab!(:no_locale_topic, :topic)

      describe "when query string is `locale:en`" do
        it "should only return topics with locale en" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("locale:en")
              .pluck(:id),
          ).to contain_exactly(en_topic.id)
        end
      end

      describe "when query string is `locale:ja,es`" do
        it "should return topics with locale ja or es" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("locale:ja,es")
              .pluck(:id),
          ).to contain_exactly(ja_topic.id, es_topic.id)
        end
      end

      describe "when query string is `locale:ja locale:es`" do
        it "should return topics with locale ja or es" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("locale:ja locale:es")
              .pluck(:id),
          ).to contain_exactly(ja_topic.id, es_topic.id)
        end
      end

      describe "when query string is `-locale:en`" do
        it "should return topics without locale en" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-locale:en")
              .pluck(:id),
          ).to contain_exactly(ja_topic.id, es_topic.id, no_locale_topic.id)
        end
      end

      describe "when query string is `-locale:en,ja`" do
        it "should return topics without locale en or ja" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-locale:en,ja")
              .pluck(:id),
          ).to contain_exactly(es_topic.id, no_locale_topic.id)
        end
      end

      describe "when query string is `locale:invalid`" do
        it "should return no topics" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("locale:invalid")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when combining with other filters" do
        before { en_topic.update!(closed: true) }

        it "should work with status:closed" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("locale:en status:closed")
              .pluck(:id),
          ).to contain_exactly(en_topic.id)
        end
      end
    end

    describe "when filtering by topic author" do
      fab!(:user2) { Fabricate(:user, username: "username2") }
      fab!(:topic_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic2_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic_by_user2) { Fabricate(:topic, user: user2) }

      describe "when query string is `created-by:@username`" do
        it "should return the topics created by the specified user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:@#{user.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id)
        end
      end

      describe "when query string is `created-by:@username2`" do
        it "should return the topics created by the specified user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:@#{user2.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:@username created-by:@username2`" do
        it "should return the topics created by either of the specified users" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "created-by:@#{user.username} created-by:@#{user2.username}",
              )
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id, topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:@username,invalid`" do
        it "should only return the topics created by the user with the valid username" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:@#{user.username},invalid")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id)
        end
      end

      describe "when query string is `created-by:@username,@username2`" do
        it "should return the topics created by either of the specified users" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:@#{user.username},@#{user2.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id, topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:@invalid`" do
        it "should not return any topics" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:@invalid")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `created-by:me`" do
        it "should return the topics created by the current user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("created-by:me")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id)
        end

        it "should not return any topics when there is no current user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:me")
              .pluck(:id),
          ).to eq([])
        end
      end
    end

    describe "when filtering by topic creator's group" do
      fab!(:group1) { Fabricate(:group, name: "group1") }
      fab!(:group2) { Fabricate(:group, name: "group2") }

      fab!(:user_in_group1) { Fabricate(:user).tap { |u| group1.add(u) } }
      fab!(:user_in_group2) { Fabricate(:user).tap { |u| group2.add(u) } }
      fab!(:user_in_both_groups) do
        Fabricate(:user).tap do |u|
          group1.add(u)
          group2.add(u)
        end
      end

      fab!(:topic_by_group1_user) { Fabricate(:topic, user: user_in_group1) }
      fab!(:topic_by_group2_user) { Fabricate(:topic, user: user_in_group2) }
      fab!(:topic_by_both_groups_user) { Fabricate(:topic, user: user_in_both_groups) }

      describe "when query string is `created-by:group1`" do
        it "should return topics created by users in the specified group" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:group1")
              .pluck(:id),
          ).to contain_exactly(topic_by_group1_user.id, topic_by_both_groups_user.id)
        end
      end

      describe "when query string is `created-by:group2`" do
        it "should return topics created by users in the specified group" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:group2")
              .pluck(:id),
          ).to contain_exactly(topic_by_group2_user.id, topic_by_both_groups_user.id)
        end
      end

      describe "when query string is `created-by:group1,group2`" do
        it "should return topics created by users in any of the specified groups" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:group1,group2")
              .pluck(:id),
          ).to contain_exactly(
            topic_by_group1_user.id,
            topic_by_group2_user.id,
            topic_by_both_groups_user.id,
          )
        end
      end

      describe "when query string is `created-by:invalid`" do
        it "should not return any topics" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:invalid")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `created-by:group1,invalid`" do
        it "should only return topics created by users in the valid group" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:group1,invalid")
              .pluck(:id),
          ).to contain_exactly(topic_by_group1_user.id, topic_by_both_groups_user.id)
        end
      end

      describe "with group visibility restrictions" do
        fab!(:private_group) do
          Fabricate(:group, visibility_level: Group.visibility_levels[:members])
        end
        fab!(:super_private_group) do
          Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
        end

        fab!(:owner_of_super_private_group) do
          Fabricate(:user).tap { |u| super_private_group.add_owner(u) }
        end

        fab!(:user_in_private_group) { Fabricate(:user).tap { |u| private_group.add(u) } }
        fab!(:user_in_super_private_group) do
          Fabricate(:user).tap { |u| super_private_group.add(u) }
        end

        fab!(:topic_by_private_group_user) { Fabricate(:topic, user: user_in_private_group) }
        fab!(:topic_by_super_private_group_owner) do
          Fabricate(:topic, user: owner_of_super_private_group)
        end
        fab!(:topic_by_super_private_group_user) do
          Fabricate(:topic, user: user_in_super_private_group)
        end
        it "should not return topics when user cannot see the group" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{private_group.name}")
              .pluck(:id),
          ).to eq([])
        end

        it "should return topics when user is a member of the private group" do
          private_group.add(user)

          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("created-by:#{private_group.name}")
              .pluck(:id),
          ).to contain_exactly(topic_by_private_group_user.id)
        end

        it "does not filter topics when user cannot see members of the group" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user_in_super_private_group))
              .filter_from_query_string("created-by:#{super_private_group.name}")
              .pluck(:id),
          ).to eq([])
        end

        it "returns topics when user can see group members" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(owner_of_super_private_group))
              .filter_from_query_string("created-by:#{super_private_group.name}")
              .pluck(:id),
          ).to contain_exactly(
            topic_by_super_private_group_owner.id,
            topic_by_super_private_group_user.id,
          )
        end
      end
    end

    shared_examples "filtering for topics by counts" do |filter|
      describe "when query string is `#{filter}-min:1`" do
        it "should only return topics with at least 1 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:1")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:3`" do
        it "should only return topics with at least 3 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:3")
              .pluck(:id),
          ).to contain_exactly(topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-max:1`" do
        it "should only return topics with at most 1 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-max:1")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id)
        end
      end

      describe "when query string is `#{filter}-max:3`" do
        it "should only return topics with at most 3 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-max:3")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:1 #{filter}-max:2`" do
        it "should only return topics with at least 1 like and at most 2 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:1 #{filter}-max:2")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id)
        end
      end

      describe "when query string is `#{filter}-min:3 #{filter}-min:2 #{filter}-max:1 #{filter}-max:3`" do
        it "should only return topics with at least 2 #{filter} and at most 3 #{filter} as it ignores earlier filters which are duplicated" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "#{filter}-min:3 #{filter}-min:2 #{filter}-max:1 #{filter}-max:3",
              )
              .pluck(:id),
          ).to contain_exactly(topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:invalid #{filter}-max:invalid`" do
        it "should ignore the filters with invalid values" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:invalid #{filter}-max:invalid")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end
    end

    describe "when filtering by number of likes in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, like_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, like_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, like_count: 3) }

      include_examples("filtering for topics by counts", "likes")
    end

    describe "when filtering by number of posters in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, participant_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, participant_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, participant_count: 3) }

      include_examples("filtering for topics by counts", "posters")
    end

    describe "when filtering by number of posts in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, posts_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, posts_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, posts_count: 3) }

      include_examples("filtering for topics by counts", "posts")
    end

    describe "when filtering by number of views in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, views: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, views: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, views: 3) }

      include_examples("filtering for topics by counts", "views")
    end

    describe "when filtering by number of likes in the first post of a topic" do
      fab!(:topic_with_1_count) do
        post = Fabricate(:post, like_count: 1)
        post.topic
      end

      fab!(:topic_with_2_count) do
        post = Fabricate(:post, like_count: 2)
        post.topic
      end

      fab!(:topic_with_3_count) do
        post = Fabricate(:post, like_count: 3)
        post.topic
      end

      include_examples("filtering for topics by counts", "likes-op")
    end

    shared_examples "filtering for topics by date column" do |filter, column, description|
      fab!(:topic) { Fabricate(:topic, column => Time.zone.local(2022, 1, 1)) }
      fab!(:topic2) { Fabricate(:topic, column => Time.zone.local(2023, 5, 12)) }

      describe "when query string is `#{filter}-after:invalid-date-test`" do
        it "should ignore the filter" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:invalid-date-test")
              .pluck(:id),
          ).to contain_exactly(topic.id, topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2022-01-01`" do
        it "should only return topics with #{description} after 2022-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2022-01-01")
              .pluck(:id),
          ).to contain_exactly(topic.id, topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2023-01-1`" do
        it "should only return topics with #{description} after 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2023-01-1")
              .pluck(:id),
          ).to contain_exactly(topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2023-6-01`" do
        it "should only return topics with #{description} after 2023-06-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2023-6-01")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `#{filter}-before:2023-01-01`" do
        it "should only return topics with #{description} before 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2023-01-01")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `#{filter}-before:2023-1-1`" do
        it "should only return topics with #{description} before 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2023-1-1")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `#{filter}-before:2000-01-01`" do
        it "should only return topics with #{description} before 2000-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2000-01-01")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `#{filter}-after:1`" do
        it "should only return topics with #{description} after 1 day ago" do
          freeze_time do
            _old_topic = Fabricate(:topic, column => 2.days.ago)
            recent_topic = Fabricate(:topic, column => Time.zone.now)

            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("#{filter}-after:1")
                .pluck(:id),
            ).to contain_exactly(recent_topic.id)
          end
        end
      end

      describe "when query string is `#{filter}-before:1`" do
        it "should only return topics with #{description} before 1 day ago" do
          freeze_time do
            old_topic = Fabricate(:topic, column => 2.days.ago)
            recent_topic = Fabricate(:topic, column => Time.zone.now)

            results =
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("#{filter}-before:1")
                .where(id: [old_topic.id, recent_topic.id])
                .pluck(:id)

            expect(results).to contain_exactly(old_topic.id)
          end
        end
      end

      describe "when query string is `#{filter}-after:0`" do
        it "should only return topics with #{description} after today" do
          freeze_time do
            _old_topic = Fabricate(:topic, column => 2.days.ago)
            recent_topic = Fabricate(:topic, column => Time.zone.now)

            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("#{filter}-after:0")
                .pluck(:id),
            ).to contain_exactly(recent_topic.id)
          end
        end
      end
    end

    describe "when filtering by activity of topics" do
      include_examples "filtering for topics by date column", "activity", :bumped_at, "bumped date"
    end

    describe "when filtering by creation date of topics" do
      include_examples "filtering for topics by date column", "created", :created_at, "created date"
    end

    describe "when filtering by last post date of topics" do
      include_examples "filtering for topics by date column",
                       "latest-post",
                       :last_posted_at,
                       "last posted date"
    end

    describe "ordering topics filter" do
      before do
        Plugin::Instance.new.add_filter_custom_filter(
          "order:wrongly",
          &->(scope) { scope.order("wrongly") }
        )
      end

      # Requires the fabrication of `topic`, `topic2` and `topic3` such that the order of the topics is `topic2`, `topic1`, `topic3`
      # when ordered by the given filter in descending order.
      shared_examples "ordering topics filters" do |order, order_description|
        describe "when query string is `order:#{order}`" do
          it "should return topics ordered by #{order_description} in descending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}")
                .pluck(:id),
            ).to eq([topic2.id, topic.id, topic3.id])
          end
        end

        describe "when query string is `order:#{order}-asc`" do
          it "should return topics ordered by #{order_description} in ascending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}-asc")
                .pluck(:id),
            ).to eq([topic3.id, topic.id, topic2.id])
          end
        end

        describe "when query string is `order:#{order}-invalid`" do
          it "should return topics ordered by the database's default order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}-invalid")
                .pluck(:id),
            ).to contain_exactly(*Topic.all.pluck(:id))
          end
        end
      end

      describe "when ordering topics by creation date" do
        fab!(:topic) { Fabricate(:topic, created_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, created_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "created", "creation date"
      end

      describe "when ordering topics by last activity date" do
        fab!(:topic) { Fabricate(:topic, bumped_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, bumped_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, bumped_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "activity", "bumped date"
      end

      describe "when ordering topics by number of likes in the topic" do
        fab!(:topic) { Fabricate(:topic, like_count: 2) }
        fab!(:topic2) { Fabricate(:topic, like_count: 3) }
        fab!(:topic3) { Fabricate(:topic, like_count: 1) }

        include_examples "ordering topics filters", "likes", "number of likes in the topic"
      end

      describe "when ordering topics by number of participants in the topic" do
        fab!(:topic) { Fabricate(:topic, participant_count: 2) }
        fab!(:topic2) { Fabricate(:topic, participant_count: 3) }
        fab!(:topic3) { Fabricate(:topic, participant_count: 1) }

        include_examples "ordering topics filters", "posters", "number of participants in the topic"
      end

      describe "when ordering topics by number of topics views" do
        fab!(:topic) { Fabricate(:topic, views: 2) }
        fab!(:topic2) { Fabricate(:topic, views: 3) }
        fab!(:topic3) { Fabricate(:topic, views: 1) }

        include_examples "ordering topics filters", "views", "number of views"
      end

      describe "when ordering topics by latest post creation date" do
        fab!(:topic) { Fabricate(:topic, last_posted_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, last_posted_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, last_posted_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "latest-post", "latest post creation date"
      end

      describe "when ordering topics by number of likes in the first post" do
        fab!(:topic) do
          post = Fabricate(:post, like_count: 2)
          post.topic
        end

        fab!(:topic2) do
          post = Fabricate(:post, like_count: 3)
          post.topic
        end

        fab!(:topic3) do
          post = Fabricate(:post, like_count: 1)
          post.topic
        end

        include_examples "ordering topics filters", "likes-op", "number of likes in the first post"
      end

      describe "when ordering by topics's category name" do
        fab!(:category) { Fabricate(:category, name: "Category 1") }
        fab!(:category2) { Fabricate(:category, name: "Category 2") }
        fab!(:category3) { Fabricate(:category, name: "Category 3") }

        fab!(:topic) { Fabricate(:topic, category: category2) }
        fab!(:topic2) { Fabricate(:topic, category: category3) }
        fab!(:topic3) { Fabricate(:topic, category: category) }

        include_examples "ordering topics filters", "category", "category name"
      end

      describe "when ordering by topics's title" do
        fab!(:topic3) { Fabricate(:topic, title: "This is topic number 1") }
        fab!(:topic2) { Fabricate(:topic, title: "This is topic Number 3") }
        fab!(:topic) { Fabricate(:topic, title: "This is topic number 2") }

        include_examples "ordering topics filters", "title", "topic's title"
      end

      describe "when ordering by user's last visit to topics" do
        fab!(:user)
        fab!(:topic)
        fab!(:topic2, :topic)
        fab!(:topic3, :topic)

        before do
          freeze_time 3.hours.ago do
            TopicUser.update_last_read(user, topic3.id, 1, 1, 0)
          end

          freeze_time 2.hours.ago do
            TopicUser.update_last_read(user, topic.id, 1, 1, 0)
          end

          freeze_time 1.hour.ago do
            TopicUser.update_last_read(user, topic2.id, 1, 1, 0)
          end
        end

        describe "when query string is `order:read`" do
          it "should return topics ordered by last visited date in descending order for logged in users" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("order:read")
                .pluck(:id),
            ).to eq([topic2.id, topic.id, topic3.id])
          end

          it "should not apply any special ordering for anonymous users" do
            topics =
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:read")
                .where(id: [topic.id, topic2.id, topic3.id])

            expect(topics.pluck(:id)).to contain_exactly(topic.id, topic2.id, topic3.id)
          end
        end

        describe "when query string is `order:read-asc`" do
          it "should return topics ordered by last visited date in ascending order for logged in users" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("order:read-asc")
                .pluck(:id),
            ).to eq([topic3.id, topic.id, topic2.id])
          end
        end
      end

      describe "composing multiple order filters" do
        fab!(:topic) { Fabricate(:topic, created_at: Time.zone.local(2023, 1, 1), views: 2) }
        fab!(:topic2) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 2) }
        fab!(:topic3) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 1) }

        describe "when query string is `order:created,views`" do
          it "should return topics ordered by creation date in descending order and then number of views in descending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:created,views")
                .pluck(:id),
            ).to eq([topic2.id, topic3.id, topic.id])
          end
        end

        describe "when query string is `order:created order:views`" do
          it "should return topics ordered by creation date in descending order and then number of views in descending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:created order:views")
                .pluck(:id),
            ).to eq([topic2.id, topic3.id, topic.id])
          end
        end
      end

      context "for DiscoursePluginRegistry.custom_filter_mappings" do
        describe "when extending order:{col}" do
          fab!(:earlier_topic) { Fabricate(:topic, bumped_at: 2.hours.ago) }
          fab!(:now_topic) { Fabricate(:topic, bumped_at: Time.now) }

          before_all do
            Plugin::Instance.new.add_filter_custom_filter(
              "order:bumped",
              &->(scope, value, _guardian) { scope.order("bumped_at #{value}") }
            )
          end

          it "applies ASC order correctly" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:bumped-asc")
                .pluck(:id),
            ).to eq([earlier_topic.id, now_topic.id])
          end

          it "applies default order correctly" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:bumped")
                .pluck(:id),
            ).to eq([now_topic.id, earlier_topic.id])
          end
        end
      end
    end

    it "performs AND search for multiple keywords" do
      SearchIndexer.enable
      post1 = Fabricate(:post, raw: "keyword1 keyword2")
      _post2 = Fabricate(:post, raw: "keyword1")
      _post3 = Fabricate(:post, raw: "keyword2")
      guardian = Guardian.new(post1.user)
      filter = TopicsFilter.new(guardian: guardian)
      scope = filter.filter_from_query_string("keyword1 keyword2")
      expect(scope.pluck(:id)).to eq([post1.topic_id])
    end

    it "excludes topics with only deleted or hidden posts from keyword search" do
      SearchIndexer.enable
      visible_post = Fabricate(:post, raw: "searchterm")
      _deleted_post = Fabricate(:post, raw: "searchterm", deleted_at: Time.zone.now)
      _hidden_post = Fabricate(:post, raw: "searchterm", hidden: true)
      _whisper_post = Fabricate(:post, raw: "searchterm", post_type: Post.types[:whisper])

      filter = TopicsFilter.new(guardian: Guardian.new)
      scope = filter.filter_from_query_string("searchterm")

      expect(scope.pluck(:id)).to contain_exactly(visible_post.topic_id)
    end

    describe "with a custom filter" do
      fab!(:topic)

      before do
        Plugin::Instance.new.add_filter_custom_filter(
          "foo",
          &->(scope, value, guardian) { guardian.is_admin? ? scope : scope.where("1=0") }
        )
      end

      it "can guard against the current user" do
        expect(
          TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("foo:bar").pluck(:id),
        ).to be_empty

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("foo:bar")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end
    end
  end

  describe "custom filter mappings for in: and status: operators" do
    fab!(:topic)
    fab!(:solved_topic) { Fabricate(:topic, closed: true) }

    describe "custom in: filter" do
      before do
        plugin_instance = Plugin::Instance.new
        DiscoursePluginRegistry.register_modifier(
          plugin_instance,
          :topics_filter_options,
        ) do |results, guardian|
          results << { name: "in:solved", description: "Topics that are solved", type: "text" }
          results
        end

        Plugin::Instance.new.add_filter_custom_filter(
          "in:solved",
          &->(scope, value, guardian) { scope.where(closed: true) }
        )
      end

      after do
        DiscoursePluginRegistry.reset_register!(:custom_filter_mappings)
        DiscoursePluginRegistry.reset_register!(:modifiers)
      end

      it "applies custom in: filter" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("in:solved")
            .pluck(:id),
        ).to contain_exactly(solved_topic.id)
      end

      it "handles comma-separated values with custom filters" do
        TopicUser.change(
          user.id,
          topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )

        TopicUser.change(
          user.id,
          solved_topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("in:watching,solved")
            .pluck(:id),
        ).to contain_exactly(solved_topic.id)
      end
    end
  end
end
