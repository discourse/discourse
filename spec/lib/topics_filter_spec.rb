# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:user) { Fabricate(:user, username: "username") }
  fab!(:admin)
  fab!(:group)

  def filtered(query, guardian = Guardian.new)
    TopicsFilter.new(guardian:).filter_from_query_string(query).pluck(:id)
  end

  describe "#option_info" do
    let(:options) { TopicsFilter.option_info(Guardian.new) }

    it "returns name and description keys for every option" do
      expect(options).to be_present
      expect(options).to all(include(:name, :description))
    end

    it "resolves a real translation for every option" do
      untranslated =
        options.select do |option|
          option[:description].blank? || option[:description].to_s.match?(/translation missing/i)
        end

      expect(untranslated.map { |option| option[:name] }).to eq([])
    end

    it "does not include tag options when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).to be_nil

      SiteSetting.tagging_enabled = true
      options = TopicsFilter.option_info(Guardian.new)

      tag_options = options.find { |o| o[:name].include? "tag" }
      expect(tag_options).not_to be_nil
    end

    it "advertises the - prefix for the group: option" do
      group_option = options.find { |o| o[:name] == "group:" }

      expect(group_option[:prefixes]).to contain_exactly(
        { name: "-", description: I18n.t("filter.description.exclude_group") },
      )
    end

    it "does not include user-specific options for anonymous users" do
      anon_options = TopicsFilter.option_info(Guardian.new)
      logged_in_options = TopicsFilter.option_info(user.guardian)

      anon_option_names = anon_options.map { |o| o[:name] }.to_set
      logged_in_option_names = logged_in_options.map { |o| o[:name] }.to_set

      user_specific_options = %w[
        in:
        in:pinned
        in:bookmarked
        bookmarked-before:
        bookmarked-after:
        in:watching
        in:tracking
        in:muted
        in:normal
        in:watching-first-post
        in:unseen
      ]

      user_specific_options.each { |option| expect(anon_option_names).not_to include(option) }
      user_specific_options.each { |option| expect(logged_in_option_names).to include(option) }
    end

    it "applies the topics_filter_options modifier for authenticated users" do
      plugin_instance = Plugin::Instance.new
      modifier =
        lambda do |results, guardian|
          if guardian.authenticated?
            results << {
              name: "custom-filter:",
              description: "A custom filter option from modifier",
              type: "text",
            }
          end
          results
        end

      DiscoursePluginRegistry.register_modifier(plugin_instance, :topics_filter_options, &modifier)

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
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :topics_filter_options,
        &modifier
      )
    end
  end

  describe "#invalid_filters" do
    fab!(:topic)

    it "reports values a known keyword does not understand" do
      filter = TopicsFilter.new(guardian: Guardian.new)
      filter.filter_from_query_string(
        "status:nonsense order:nonsense in:nonsense views-min:abc created-after:2024-13-45",
      )

      expect(filter.invalid_filters).to contain_exactly(
        "status:nonsense",
        "order:nonsense",
        "in:nonsense",
        "views-min:abc",
        "created-after:2024-13-45",
      )
    end

    it "reports only the bad value when a keyword repeats with a good and a bad one" do
      chatty = Fabricate(:topic, posts_count: 10)
      quiet = Fabricate(:topic, posts_count: 1)

      ["posts-min:10 -posts-min:abc", "-posts-min:abc posts-min:10"].each do |query|
        filter = TopicsFilter.new(guardian: Guardian.new)
        ids = filter.filter_from_query_string(query).pluck(:id)

        expect(filter.invalid_filters).to contain_exactly("posts-min:abc"), query
        expect(ids).to include(chatty.id), query
        expect(ids).not_to include(quiet.id), query
      end
    end

    it "reports an invalid bookmark date" do
      filter = TopicsFilter.new(guardian: user.guardian)
      filter.filter_from_query_string("bookmarked-after:2024-13-45")

      expect(filter.invalid_filters).to contain_exactly("bookmarked-after:2024-13-45")
    end

    it "reports invalid values on negated keywords" do
      filter = TopicsFilter.new(guardian: Guardian.new)
      filter.filter_from_query_string("-status:nonsense -in:nonsense")

      expect(filter.invalid_filters).to contain_exactly("status:nonsense", "in:nonsense")
    end

    it "does not report free text that happens to contain a colon" do
      filter = TopicsFilter.new(guardian: Guardian.new)
      filter.filter_from_query_string("outage https://status.example.com standup at 12:30")

      expect(filter.invalid_filters).to eq([])
    end

    it "does not report user-specific in: values for anonymous users" do
      filter = TopicsFilter.new(guardian: Guardian.new)
      filter.filter_from_query_string("in:bookmarked")

      expect(filter.invalid_filters).to eq([])
    end

    it "is empty for a query it fully understands" do
      filter = TopicsFilter.new(guardian: Guardian.new)
      filter.filter_from_query_string("status:open order:created")

      expect(filter.invalid_filters).to eq([])
    end
  end

  describe "scope defaulting" do
    it "does not expose topics in categories the guardian cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      hidden = Fabricate(:topic, category: private_category)
      visible = Fabricate(:topic)

      ids = filtered("")

      expect(ids).to include(visible.id)
      expect(ids).not_to include(hidden.id)
    end
  end

  describe "#filter_from_query_string" do
    it "preserves extra selected columns when negating a filter" do
      open_topic = Fabricate(:topic)
      Fabricate(:topic, closed: true)
      scope = Topic.select("topics.*, topics.id AS custom_id")

      topics =
        TopicsFilter.new(guardian: user.guardian, scope:).filter_from_query_string("-status:closed")

      expect(topics.map(&:id)).to contain_exactly(open_topic.id)
      expect(topics.first.custom_id).to eq(open_topic.id)
    end

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
        ids = filtered("users:alice")
        expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
        expect(ids).not_to include(topic_by_u2.id)
      end

      it "-users:alice excludes topics where alice participated" do
        ids = filtered("-users:alice")
        expect(ids).to include(topic_by_u2.id)
        expect(ids).not_to include(topic_by_u1.id, topic_by_u1_and_u2.id)
      end

      it "users:alice,bob returns topics with either alice or bob" do
        ids = filtered("users:alice,bob")
        expect(ids).to include(topic_by_u1.id, topic_by_u2.id, topic_by_u1_and_u2.id)
      end

      it "users:alice+bob returns only topics where both participated/allowed" do
        ids = filtered("users:alice+bob")
        expect(ids).to contain_exactly(topic_by_u1_and_u2.id)
      end

      it "-users:alice,bob returns topics where neither alice nor bob participated" do
        post = Fabricate(:post)
        ids = filtered("-users:alice,bob")
        expect(ids).to contain_exactly(post.topic_id)
      end

      it "-users:alice+bob returns topics where bob and alice did not participate together" do
        ids = filtered("-users:alice+bob")
        expect(ids).to contain_exactly(topic_by_u1.id, topic_by_u2.id)
      end

      it "-user:alice,bob (alias) returns topics where neither alice nor bob participated" do
        ids = filtered("-user:alice,bob")
        expect(ids).to contain_exactly()
      end

      it "group:group1 returns topics with participants from the group or group-allowed PMs" do
        ids = filtered("group:group1")
        expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id)
      end

      it "groups:group1,group2 returns union of both groups" do
        ids = filtered("groups:group1,group2")
        expect(ids).to include(topic_by_u1.id, topic_by_u2.id, topic_by_u1_and_u2.id)
      end

      it "group:group1+group2 returns only topics with both groups represented" do
        ids = filtered("group:group1+group2")
        expect(ids).to contain_exactly(topic_by_u1_and_u2.id)
      end

      it "-group:group1 returns topics without participants from the group" do
        topic_by_u3 = Fabricate(:post, user: u3).topic
        ids = filtered("-group:group1")
        expect(ids).to contain_exactly(topic_by_u2.id, topic_by_u3.id)
      end

      it "-groups:group1,group2 returns topics with participants from neither group" do
        topic_by_u3 = Fabricate(:post, user: u3).topic
        ids = filtered("-groups:group1,group2")
        expect(ids).to contain_exactly(topic_by_u3.id)
      end

      it "-group:group1+group2 returns topics where both groups are not represented together" do
        ids = filtered("-group:group1+group2")
        expect(ids).to contain_exactly(topic_by_u1.id, topic_by_u2.id)
      end

      it "reports a negated value that mixes the + and , delimiters" do
        %w[-users:alice+bob,cara -group:group1+group2,group2].each do |query|
          filter = TopicsFilter.new(guardian: Guardian.new)
          filter.filter_from_query_string(query)

          expect(filter.invalid_filters).to contain_exactly(query.delete_prefix("-")), query
        end
      end

      it "is a no-op when a negated group cannot be resolved" do
        all_ids = [topic_by_u1.id, topic_by_u2.id, topic_by_u1_and_u2.id]

        expect(filtered("-group:missing")).to contain_exactly(*all_ids)
        expect(filtered("-group:group1+missing")).to contain_exactly(*all_ids)
      end

      it "ignores deleted posts when matching group participation" do
        topic = Fabricate(:topic)
        Fabricate(:post, topic:, user: u1).update_column(:deleted_at, Time.zone.now)
        Fabricate(:post, topic:, user: u2)

        expect(filtered("-group:group1")).to include(topic.id)
        expect(filtered("group:group1")).not_to include(topic.id)
        expect(filtered("group:group1+group2")).not_to include(topic.id)
      end

      context "with whispers" do
        fab!(:whisperer_group, :group)
        fab!(:whisperer_user) { Fabricate(:user).tap { |u| whisperer_group.add(u) } }
        fab!(:regular_user, :user)
        fab!(:topic_with_whisper_only) do
          Fabricate(:post, user: u1, post_type: Post.types[:whisper]).topic
        end

        before { SiteSetting.whispers_allowed_groups = "#{whisperer_group.id}" }

        it "hides whisper-only participation from non-whisperers" do
          %w[users:alice group:group1].each do |query|
            ids = filtered(query, Guardian.new(regular_user))

            expect(ids).not_to include(topic_with_whisper_only.id), query
            expect(ids).to include(topic_by_u1.id, topic_by_u1_and_u2.id), query
          end
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
        expect(filtered("order:hot")).to start_with(t2.id, t1.id)
      end

      it "order:hot-asc sorts ascending" do
        expect(filtered("order:hot-asc")).to start_with(t1.id, t2.id)
      end
    end

    describe "when filtering with multiple filters" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:closed_topic_with_tag) { Fabricate(:topic, tags: [tag], closed: true) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:closed_topic_with_tag2) { Fabricate(:topic, tags: [tag2], closed: true) }

      it "returns matching topics for `status:closed tags:tag1,tag2`" do
        expect(filtered("status:closed tags:tag1,tag2")).to contain_exactly(
          closed_topic_with_tag.id,
          closed_topic_with_tag2.id,
        )
      end
    end

    describe "when filtering with the `in` filter" do
      fab!(:topic, :topic_with_op)

      fab!(:pinned_topic) do
        Fabricate(:topic_with_op, pinned_at: Time.zone.now, pinned_until: 1.hour.from_now)
      end

      fab!(:expired_pinned_topic) do
        Fabricate(:topic, pinned_at: 2.hours.ago, pinned_until: 1.hour.ago)
      end

      describe "when query string is `in:untagged`" do
        it "returns only topics without tags" do
          SiteSetting.tagging_enabled = true
          untagged = Fabricate(:topic)
          tagged = Fabricate(:topic, tags: [Fabricate(:tag)])

          ids = filtered("in:untagged")

          expect(ids).to include(untagged.id)
          expect(ids).not_to include(tagged.id)
        end
      end

      describe "when query string is `in:pinned`" do
        it "returns pinned topics" do
          expect(filtered("in:pinned")).to contain_exactly(pinned_topic.id)
        end

        it "returns topics pinned without an expiry date" do
          permanent = Fabricate(:topic, pinned_at: Time.zone.now, pinned_until: nil)

          expect(filtered("in:pinned")).to include(permanent.id)
        end

        it "does not return expired pinned topics" do
          freeze_time(2.hours.from_now) { expect(filtered("in:pinned")).to eq([]) }
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
          ids = filtered("in:new-topics", user_for_new_filters.guardian)
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
          expect(filtered("in:new")).to be_empty
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

        it "returns no topics for an anonymous user" do
          expect(filtered("in:bookmarked")).to eq([])
        end

        it "returns bookmarked topics" do
          expect(filtered("in:bookmarked", Guardian.new(user))).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `in:bookmarked in:pinnned`" do
        it "returns topics that are bookmarked and pinned" do
          expect(filtered("in:bookmarked in:pinned", Guardian.new(user))).to eq([])

          BookmarkManager.new(user).create_for(
            bookmarkable_id: pinned_topic.id,
            bookmarkable_type: "Topic",
          )

          expect(filtered("in:bookmarked in:pinned", Guardian.new(user))).to contain_exactly(
            pinned_topic.id,
          )
        end
      end

      it "returns topics matching each topic notification level" do
        topics =
          TopicUser.notification_levels.values.uniq.to_h do |value|
            topic = Fabricate(:topic)
            TopicUser.change(user.id, topic.id, notification_level: value)
            [value, topic]
          end

        TopicUser.notification_levels.each do |level, value|
          expect(filtered("in:#{level}", user.guardian)).to contain_exactly(topics[value].id),
          "in:#{level}"
        end
      end

      it "returns no topics for a notification level filter when the user is anonymous" do
        expect(filtered("in:watching")).to eq([])
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
          it "ignores the invalid notification level" do
            expect(filtered("in:muted,invalid", Guardian.new(user))).to contain_exactly(
              user_muted_topic.id,
            )
          end
        end

        describe "when query string is `in:muted in:tracking`" do
          it "returns topics that the user is tracking or has muted" do
            expect(filtered("in:muted in:tracking", Guardian.new(user))).to contain_exactly(
              user_muted_topic.id,
              user_tracking_topic.id,
            )
          end
        end

        describe "when query string is `in:muted,tracking" do
          it "returns tracked or muted topics" do
            expect(filtered("in:muted,tracking", Guardian.new(user))).to contain_exactly(
              user_muted_topic.id,
              user_tracking_topic.id,
            )
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

        it "returns no topics when the user is anonymous" do
          expect(filtered("in:watching_first_post")).to be_empty
        end

        it "returns the union of watched-category and watched-tag topics" do
          expected = [topic_in_watched_category.id, topic_with_watched_tag.id, topic_with_both.id]

          %w[in:watching_first_post in:watching-first-post].each do |query|
            ids = filtered(query, Guardian.new(user))

            expect(ids).to contain_exactly(*expected), query
          end
        end

        it "combines with other filters" do
          topic_in_watched_category.update!(closed: true)

          ids = filtered("in:watching_first_post status:closed", Guardian.new(user))

          expect(ids).to contain_exactly(topic_in_watched_category.id)
        end

        it "accepts comma-separated notification levels" do
          user_watching_topic =
            Fabricate(:topic).tap do |topic|
              TopicUser.change(
                user.id,
                topic.id,
                notification_level: TopicUser.notification_levels[:watching],
              )
            end

          ids = filtered("in:watching,watching_first_post", Guardian.new(user))

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

      around do |example|
        registered = DiscoursePluginRegistry._raw_custom_filter_mappings.dup
        example.run
      ensure
        DiscoursePluginRegistry._raw_custom_filter_mappings.replace(registered)
      end

      it "supports a custom filter" do
        plugin.add_filter_custom_filter("word_count", &word_count_block)

        expect(filtered("word_count:42")).to contain_exactly(
          word_count_topic.id,
          word_count_topic_2.id,
        )
      end

      it "supports multiple custom filters" do
        plugin.add_filter_custom_filter("word_count", &word_count_block)
        plugin.add_filter_custom_filter("id", &id_block)

        expect(filtered("word_count:42 id:#{word_count_topic.id}")).to contain_exactly(
          word_count_topic.id,
        )
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

      it "returns no topics when the category value cannot be parsed" do
        expect(filtered("category:category+category2")).to eq([])
      end

      it "returns topics from the specified category and its subcategories" do
        expect(filtered("category:category")).to contain_exactly(
          topic_in_category.id,
          topic_in_category_subcategory.id,
        )
      end

      it "returns topics from every descendant category" do
        SiteSetting.max_category_nesting = 3

        category_subcategory_subcategory =
          Fabricate(
            :category,
            parent_category: category_subcategory,
            name: "category subcategory subcategory",
          )

        topic_in_category_subcategory_subcategory =
          Fabricate(:topic, category: category_subcategory_subcategory)

        expect(filtered("category:category")).to contain_exactly(
          topic_in_category.id,
          topic_in_category_subcategory.id,
          topic_in_category_subcategory_subcategory.id,
        )
      end

      it "unions categories given as a comma list or as repeated keys" do
        expected = [
          topic_in_category.id,
          topic_in_category_subcategory.id,
          topic_in_category2.id,
          topic_in_category2_subcategory.id,
        ]

        expect(filtered("category:category,category2")).to contain_exactly(*expected)
        expect(filtered("category:category category:category2")).to contain_exactly(*expected)
      end

      it "includes descendants only for the categories without the = prefix" do
        expect(filtered("category:category =category:category2")).to contain_exactly(
          topic_in_category.id,
          topic_in_category_subcategory.id,
          topic_in_category2.id,
        )
      end

      it "excludes the specified categories and their subcategories" do
        expect(filtered("-category:category")).to contain_exactly(
          topic_in_category2.id,
          topic_in_category2_subcategory.id,
        )

        expect(filtered("-category:category2,category")).to eq([])

        expect(filtered("-category:category -category:category2-subcategory")).to contain_exactly(
          topic_in_category2.id,
        )
      end

      it "restricts to the category itself with the = prefix" do
        expect(filtered("=category:category")).to contain_exactly(topic_in_category.id)

        expect(filtered("=category:category,category2")).to contain_exactly(
          topic_in_category.id,
          topic_in_category2.id,
        )

        expect(filtered("-=category:category")).to contain_exactly(
          topic_in_category_subcategory.id,
          topic_in_category2.id,
          topic_in_category2_subcategory.id,
        )

        expect(filtered("-=category:category,category2")).to contain_exactly(
          topic_in_category_subcategory.id,
          topic_in_category2_subcategory.id,
        )
      end

      it "returns the descendants of a category except the one excluded with -=" do
        expect(
          filtered("category:category2 -=category:category2:category2-subcategory"),
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

        it "keeps the topics nested below the category excluded with -=" do
          expect(
            filtered("category:category2 -=category:category2:category2-subcategory"),
          ).to contain_exactly(topic_in_category2.id, topic_in_category2_subcategory_subcategory.id)
        end
      end

      describe "when `slug_generation_method` site setting is set to encoded" do
        before do
          SiteSetting.slug_generation_method = "encoded"
          category.update!(name: "日本語", slug: "日本語")
        end

        it "resolves encoded slugs, including a parent:child chain" do
          expect(filtered("category:日本語")).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
          )

          category_subcategory.update!(name: "안녕하세요 ", slug: "안녕하세요 ")

          expect(filtered("category:日本語:안녕하세요")).to contain_exactly(
            topic_in_category_subcategory.id,
          )
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

        it "disambiguates same-named subcategories by their ancestor chain" do
          expect(filtered("category:subcategory")).to contain_exactly(
            topic_in_category_subcategory.id,
            topic_in_category2_subcategory.id,
            topic_in_category_subcategory_subcategory.id,
            topic_in_category2_subcategory_subcategory.id,
          )

          expect(filtered("category:category:subcategory")).to contain_exactly(
            topic_in_category_subcategory.id,
            topic_in_category_subcategory_subcategory.id,
          )

          expect(filtered("category:category2:subcategory")).to contain_exactly(
            topic_in_category2_subcategory.id,
            topic_in_category2_subcategory_subcategory.id,
          )

          expect(
            filtered("category:category:subcategory,category2:subcategory"),
          ).to contain_exactly(
            topic_in_category_subcategory.id,
            topic_in_category2_subcategory.id,
            topic_in_category_subcategory_subcategory.id,
            topic_in_category2_subcategory_subcategory.id,
          )
        end

        it "resolves a slug chain three categories deep" do
          category2_subcategory_subcategory2 =
            Fabricate(:category, parent_category: category2_subcategory, name: "sub-subcategory2")

          topic_in_category2_subcategory_subcategory2 =
            Fabricate(:topic, category: category2_subcategory_subcategory2)

          expect(filtered("category:category:subcategory:sub-subcategory")).to contain_exactly(
            topic_in_category_subcategory_subcategory.id,
          )

          expect(filtered("=category:category2:subcategory")).to contain_exactly(
            topic_in_category2_subcategory.id,
          )

          expect(filtered("category:category2:subcategory")).to contain_exactly(
            topic_in_category2_subcategory.id,
            topic_in_category2_subcategory_subcategory.id,
            topic_in_category2_subcategory_subcategory2.id,
          )

          expect(filtered("category:sub-subcategory")).to contain_exactly(
            topic_in_category_subcategory_subcategory.id,
            topic_in_category2_subcategory_subcategory.id,
          )
        end
      end
    end

    describe "when filtering by status" do
      fab!(:topic)
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:archived_topic) { Fabricate(:topic, archived: true) }
      fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }
      fab!(:foobar_topic) { Fabricate(:topic, closed: true, word_count: 42) }

      around do |example|
        registered = TopicsFilter.custom_status_filters.dup
        example.run
      ensure
        TopicsFilter.custom_status_filters.replace(registered)
      end

      context "with custom status filters" do
        let(:enabled?) { true }

        before do
          TopicsFilter.add_filter_by_status("foobar", enabled: method(:enabled?)) do |scope|
            scope.where("word_count = 42")
          end
        end

        it "applies the custom filter" do
          expect(filtered("status:foobar")).to contain_exactly(foobar_topic.id)
        end

        context "when the filter is disabled" do
          let(:enabled?) { false }

          it "does not apply the custom filter" do
            expect(filtered("status:foobar")).to contain_exactly(*Topic.all.pluck(:id))
          end
        end
      end

      it "returns only open topics for `status:open`" do
        expect(filtered("status:open")).to contain_exactly(topic.id)
      end

      it "returns only deleted topics for authorized users with `status:deleted`" do
        expect(filtered("status:deleted", Guardian.new(admin))).to contain_exactly(deleted_topic_id)
      end

      it "returns nothing for `status:deleted` when the user cannot see deleted topics" do
        expect(filtered("status:deleted")).to eq([])
      end

      it "returns only archived topics for `status:archived`" do
        expect(filtered("status:archived")).to contain_exactly(archived_topic.id)
      end

      it "returns only visible topics for `status:listed`" do
        Topic.update_all(visible: false)
        topic.update!(visible: true)

        expect(filtered("status:listed")).to contain_exactly(topic.id)
      end

      it "returns only unlisted topics for `status:unlisted`" do
        Topic.update_all(visible: true)
        topic.update!(visible: false)

        expect(filtered("status:unlisted")).to contain_exactly(topic.id)
      end

      it "returns only unrestricted topics for `status:public`" do
        private_category = Fabricate(:private_category, group: group)
        topic_in_private_category = Fabricate(:topic, category: private_category)

        # An admin can see the restricted topic, so the filter is what removes it here,
        # not the guardian.
        expect(filtered("", admin.guardian)).to include(topic_in_private_category.id)

        expect(filtered("status:public", admin.guardian)).not_to include(
          topic_in_private_category.id,
        )
      end

      describe "when query string is `status:closed status:unlisted`" do
        fab!(:closed_and_unlisted_topic) { Fabricate(:topic, closed: true, visible: false) }

        it "returns only closed and unlisted topics" do
          expect(filtered("status:closed status:unlisted")).to contain_exactly(
            closed_and_unlisted_topic.id,
          )
        end
      end

      describe "when query string is `status:noreplies`" do
        fab!(:topic_without_replies) { Fabricate(:topic, posts_count: 1) }
        fab!(:topic_with_replies) { Fabricate(:topic, posts_count: 2) }

        it "returns only topics without replies" do
          expect(filtered("status:noreplies")).to contain_exactly(topic_without_replies.id)
        end
      end

      describe "when query string is `status:single-user`" do
        fab!(:single_user_topic) { Fabricate(:topic, participant_count: 1) }
        fab!(:multi_user_topic) { Fabricate(:topic, participant_count: 2) }

        it "returns only topics with one participant, in either spelling" do
          %w[status:single-user status:single_user].each do |query|
            topic_ids = filtered(query)

            expect(topic_ids).to include(single_user_topic.id), query
            expect(topic_ids).not_to include(multi_user_topic.id), query
          end
        end
      end
    end

    describe "when filtering by scheduled publication" do
      fab!(:destination, :category)
      fab!(:scheduled_topic, :topic)
      fab!(:unscheduled_topic, :topic)
      fab!(:closing_topic, :topic)

      before do
        Fabricate(
          :topic_timer,
          topic: scheduled_topic,
          status_type: TopicTimer.types[:publish_to_category],
          category: destination,
        )

        Fabricate(:topic_timer, topic: closing_topic, status_type: TopicTimer.types[:close])
      end

      it "returns only topics scheduled to publish for `status:scheduled`" do
        expect(filtered("status:scheduled")).to contain_exactly(scheduled_topic.id)
      end

      it "excludes topics scheduled to publish for `-status:scheduled`" do
        ids = filtered("-status:scheduled")

        expect(ids).to include(unscheduled_topic.id, closing_topic.id)
        expect(ids).not_to include(scheduled_topic.id)
      end

      it "ignores a timer that has been trashed" do
        TopicTimer.find_by(timerable_id: scheduled_topic.id).trash!

        expect(filtered("status:scheduled")).to eq([])
      end
    end

    describe "when negating a filter" do
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:open_topic, :topic)
      fab!(:popular_topic) { Fabricate(:topic, views: 100) }

      it "excludes whatever the positive form would have included" do
        authored = Fabricate(:topic, user: user)

        {
          "-status:closed" => closed_topic,
          "-views-min:100" => popular_topic,
          "-created-by:username" => authored,
        }.each do |query, excluded|
          ids = filtered(query)

          expect(ids).to include(open_topic.id), query
          expect(ids).not_to include(excluded.id), query
        end
      end

      it "negates a status registered by a plugin" do
        TopicsFilter.add_filter_by_status("wordy") { |scope| scope.where("word_count = 42") }
        wordy = Fabricate(:topic, word_count: 42)

        ids = filtered("-status:wordy")

        expect(ids).to include(open_topic.id)
        expect(ids).not_to include(wordy.id)
      ensure
        TopicsFilter.custom_status_filters.delete("wordy")
      end

      it "keeps the topic_users join available to a later filter" do
        muted = Fabricate(:topic)
        TopicUser.create!(user: user, topic: muted, notification_level: 0)
        bookmarked = Fabricate(:topic)
        TopicUser.create!(user: user, topic: bookmarked, notification_level: 1, bookmarked: true)

        expect(filtered("-in:muted in:bookmarked", Guardian.new(user))).to contain_exactly(
          bookmarked.id,
        )
      end

      it "is a no-op when the negated filter matches nothing it can act on" do
        all_ids = Topic.pluck(:id)

        expect(filtered("-foo:bar")).to match_array(all_ids)

        expect(filtered("-views-min:notanumber")).to match_array(all_ids)

        expect(filtered("-category:category+category2")).to match_array(all_ids)
      end

      it "excludes each value separately when a keyword is negated twice" do
        archived = Fabricate(:topic, archived: true)

        ids = filtered("-status:closed -status:archived")

        expect(ids).to include(open_topic.id)
        expect(ids).not_to include(closed_topic.id, archived.id)
      end

      it "does not leak notification levels from the positive pass into the negated one" do
        tracking = Fabricate(:topic)
        TopicUser.create!(user: user, topic: tracking, notification_level: 2)
        watching = Fabricate(:topic)
        TopicUser.create!(user: user, topic: watching, notification_level: 3)

        expect(filtered("in:tracking -in:watching", Guardian.new(user))).to contain_exactly(
          tracking.id,
        )
      end

      it "still sorts for `-order:views`, since a sort has no negation" do
        expect(filtered("-order:views").first).to eq(popular_topic.id)
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
      fab!(:tag_synonym) { Fabricate(:tag, name: "synonym1", target_tag_id: tag.id) }

      describe "when filtering by a tag synonym" do
        it "returns topics with the target tag for `tag:synonym1`" do
          expect(filtered("tag:synonym1")).to contain_exactly(
            topic_with_tag.id,
            topic_with_tag_and_tag2.id,
          )
        end

        it "returns topics with the target or other tags for `tags:synonym1,tag2`" do
          expect(filtered("tags:synonym1,#{tag2.name}")).to contain_exactly(
            topic_with_tag.id,
            topic_with_tag_and_tag2.id,
            topic_with_tag2.id,
          )
        end

        it "excludes topics with the target tag for `-tag:synonym1`" do
          expect(filtered("-tag:synonym1")).to contain_exactly(
            topic_without_tag.id,
            topic_with_tag2.id,
            topic_with_group_only_tag.id,
          )
        end
      end

      it "does not filter topics by tag when tagging is disabled" do
        SiteSetting.tagging_enabled = false

        expect(filtered("tags:#{tag.name}+#{tag2.name}")).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "returns only topics with all tags for `tags:tag1+tag2`" do
        expect(filtered("tags:#{tag.name}+#{tag2.name}")).to contain_exactly(
          topic_with_tag_and_tag2.id,
        )
      end

      it "returns topics with period-delimited tag names" do
        tag_with_period = Fabricate(:tag, name: "node.js")
        topic_with_period_tag = Fabricate(:topic, tags: [tag_with_period])

        expect(filtered("tags:#{tag_with_period.name}")).to contain_exactly(
          topic_with_period_tag.id,
        )
      end

      it "returns only topics with tag1 and tag2 for repeated tag filters" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(filtered("tags:#{tag.name} tags:#{tag2.name}")).to contain_exactly(
          topic_with_tag_and_tag2.id,
          topic_with_tag_and_tag2_and_tag3.id,
        )
      end

      describe "when query string is `tags:front-end,back-end tags:pri-high,pri-low`" do
        fab!(:front_end) { Fabricate(:tag, name: "front-end") }
        fab!(:back_end) { Fabricate(:tag, name: "back-end") }
        fab!(:pri_high) { Fabricate(:tag, name: "pri-high") }
        fab!(:pri_low) { Fabricate(:tag, name: "pri-low") }

        it "returns topics matching each requested tag combination" do
          topic_with_front_end_pri_high = Fabricate(:topic, tags: [front_end, pri_high])
          topic_with_front_end_pri_low = Fabricate(:topic, tags: [front_end, pri_low])
          topic_with_back_end_pri_high = Fabricate(:topic, tags: [back_end, pri_high])
          topic_with_back_end_pri_low = Fabricate(:topic, tags: [back_end, pri_low])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [front_end, back_end])

          expect(
            filtered(
              "tags:#{front_end.name},#{back_end.name} tags:#{pri_high.name},#{pri_low.name}",
            ),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_back_end_pri_high.id,
            topic_with_back_end_pri_low.id,
          )
        end

        it "returns topics matching either requested tag combination" do
          topic_with_front_end_back_end_pri_low =
            Fabricate(:topic, tags: [front_end, back_end, pri_low])
          topic_with_front_end_back_end_pri_high =
            Fabricate(:topic, tags: [front_end, back_end, pri_high])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [front_end, back_end])

          expect(
            filtered(
              "tags:#{front_end.name},#{back_end.name} tags:#{pri_low.name},#{pri_high.name}",
            ),
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

        it "returns topics with front-end and either priority tag" do
          topic_with_front_end_pri_high = Fabricate(:topic, tags: [front_end, pri_high])
          topic_with_front_end_pri_low = Fabricate(:topic, tags: [front_end, pri_low])
          topic_with_front_end_pri_high_pri_low =
            Fabricate(:topic, tags: [front_end, pri_high, pri_low])

          Fabricate(:topic, tags: [pri_low, pri_high])
          Fabricate(:topic, tags: [pri_high, pri_low])

          expect(
            filtered("tags:#{front_end.name} tags:#{pri_high.name},#{pri_low.name}"),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_front_end_pri_high_pri_low.id,
          )

          expect(
            filtered("tags:#{pri_high.name},#{pri_low.name} tags:#{front_end.name}"),
          ).to contain_exactly(
            topic_with_front_end_pri_high.id,
            topic_with_front_end_pri_low.id,
            topic_with_front_end_pri_high_pri_low.id,
          )
        end
      end

      it "returns topics with tag1 and tag2 but without tag3" do
        _topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(filtered("tags:#{tag.name} tags:#{tag2.name} -tags:tag3")).to contain_exactly(
          topic_with_tag_and_tag2.id,
        )
      end

      it "returns topics with any specified tag for `tags:tag1,tag2`" do
        expect(filtered("tags:#{tag.name},#{tag2.name}")).to contain_exactly(
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
        )
      end

      it "returns no topics when an AND tag filter includes an invalid tag" do
        expect(filtered("tags:tag1+tag2+invalid")).to eq([])
      end

      it "filters by valid tags when an OR tag filter includes an invalid tag" do
        expect(filtered("tags:tag1,tag2,invalid")).to contain_exactly(
          topic_with_tag_and_tag2.id,
          topic_with_tag.id,
          topic_with_tag2.id,
        )
      end

      it "returns no topics when the specified tag is hidden from the user" do
        expect(filtered("tags:group-only-tag")).to eq([])
      end

      it "returns matching topics when the user can access the specified tag" do
        group.add(admin)

        expect(filtered("tags:group-only-tag", Guardian.new(admin))).to contain_exactly(
          topic_with_group_only_tag.id,
        )
      end

      it "returns only topics without the specified tag for `-tags:tag1`" do
        expect(filtered("-tags:tag1")).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "excludes topics with all specified tags for `-tags:tag1+tag2`" do
        expect(filtered("-tags:tag1+tag2")).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "excludes topics with any specified tag for `-tags:tag1,tag2`" do
        expect(filtered("-tags:tag1,tag2")).to contain_exactly(
          topic_without_tag.id,
          topic_with_group_only_tag.id,
        )
      end

      it "keeps applying tag filters after one with an unsupported prefix" do
        filter = TopicsFilter.new(guardian: Guardian.new)
        ids = filter.filter_from_query_string("=tags:#{tag.name} tags:#{tag2.name}").pluck(:id)

        expect(filter.invalid_filters).to contain_exactly("=tag:#{tag.name}")
        expect(ids).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag2.id)
      end

      it "reports an unparseable tag value and returns no topics" do
        filter = TopicsFilter.new(guardian: Guardian.new)

        expect(filter.filter_from_query_string("tags:!!!").pluck(:id)).to eq([])
        expect(filter.invalid_filters).to contain_exactly("tag:!!!")
      end

      it "orders by an expression while filtering by tags" do
        expect(filtered("tags:#{tag.name},#{tag2.name} order:title")).to contain_exactly(
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
        )
      end

      describe "when query string is tag:日べé1" do
        before { tag.update!(name: "日べé1") }

        it "returns topics with the specified tag" do
          expect(filtered("tag:日べé1")).to contain_exactly(
            topic_with_tag.id,
            topic_with_tag_and_tag2.id,
          )
        end
      end

      describe "when query string contains multiple tags with underscores" do
        before do
          tag.update!(name: "tag_one")
          tag2.update!(name: "tag_two")
        end

        it "returns topics for comma-separated tags containing underscores" do
          expect(filtered("tags:tag_one,tag_two")).to contain_exactly(
            topic_with_tag.id,
            topic_with_tag_and_tag2.id,
            topic_with_tag2.id,
          )
        end

        it "returns topics for plus-separated tags containing underscores" do
          expect(filtered("tags:tag_one+tag_two")).to contain_exactly(topic_with_tag_and_tag2.id)
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

      it "returns topics with any tag in the specified tag group" do
        expect(filtered("tag-group:#{tag_group.name}")).to contain_exactly(
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
        )
      end

      it "excludes topics with tags in the specified excluded tag group" do
        expect(filtered("-tag_group:#{tag_group.name}")).to contain_exactly(
          topic_with_tag3.id,
          topic_without_tag.id,
          topic_with_staff_only_tag.id,
        )
      end

      it "excludes a topic that has only one of its tags in the excluded tag group" do
        mixed_topic = Fabricate(:topic, tags: [tag, tag3])

        expect(filtered("-tag_group:#{tag_group.name}")).not_to include(mixed_topic.id)
      end

      it "orders by an expression while filtering by tag group" do
        expect(filtered("tag_group:#{tag_group.name} order:title")).to contain_exactly(
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
        )
      end

      it "returns matching topics when the user can access the tag group" do
        group.add(admin)

        expect(
          filtered("tag_group:#{staff_tag_group.name}", Guardian.new(admin)),
        ).to contain_exactly(topic_with_staff_only_tag.id)
      end

      it "returns no topics when the tag group is hidden from the user" do
        expect(filtered("tag_group:#{staff_tag_group.name}")).to eq([])
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

      it "resolves tag group names regardless of quoting, casing, or punctuation" do
        expect(filtered('tag_group:"My Tag Group"')).to contain_exactly(topic_with_tag.id)
        expect(filtered("tag_group:'My Tag Group'")).to contain_exactly(topic_with_tag.id)
        expect(filtered('tag_group:"MY TAG GROUP"')).to contain_exactly(topic_with_tag.id)
        expect(filtered('tag_group:"News & Updates"')).to contain_exactly(topic_with_tag.id)
        expect(filtered('tag_group:"Group (Test)"')).to contain_exactly(topic_with_tag.id)
      end

      it "handles the exclusion prefix with quoted tag group names" do
        expect(filtered('-tag_group:"My Tag Group"')).to contain_exactly(topic_without_tag.id)
      end
    end

    describe "when filtering by locale" do
      fab!(:en_topic) { Fabricate(:topic, locale: "en") }
      fab!(:ja_topic) { Fabricate(:topic, locale: "ja") }
      fab!(:es_topic) { Fabricate(:topic, locale: "es") }
      fab!(:no_locale_topic, :topic)

      describe "when query string is `locale:en`" do
        it "returns only topics with the en locale" do
          expect(filtered("locale:en")).to contain_exactly(en_topic.id)
        end
      end

      describe "when query string is `locale:ja,es`" do
        it "returns topics with the ja or es locale" do
          expect(filtered("locale:ja,es")).to contain_exactly(ja_topic.id, es_topic.id)
        end
      end

      describe "when query string is `locale:ja locale:es`" do
        it "returns topics matching either ja or es locale filter" do
          expect(filtered("locale:ja locale:es")).to contain_exactly(ja_topic.id, es_topic.id)
        end
      end

      describe "when query string is `-locale:en`" do
        it "returns topics without the en locale" do
          expect(filtered("-locale:en")).to contain_exactly(
            ja_topic.id,
            es_topic.id,
            no_locale_topic.id,
          )
        end
      end

      describe "when query string is `-locale:en,ja`" do
        it "returns topics without the en or ja locale" do
          expect(filtered("-locale:en,ja")).to contain_exactly(es_topic.id, no_locale_topic.id)
        end
      end

      describe "when query string is `locale:invalid`" do
        it "returns no topics" do
          expect(filtered("locale:invalid")).to eq([])
        end
      end

      describe "when combining with other filters" do
        before { en_topic.update!(closed: true) }

        it "combines with status:closed" do
          expect(filtered("locale:en status:closed")).to contain_exactly(en_topic.id)
        end
      end
    end

    describe "when filtering by topic author" do
      fab!(:user2) { Fabricate(:user, username: "username2") }
      fab!(:topic_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic2_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic_by_user2) { Fabricate(:topic, user: user2) }

      describe "when query string is `created-by:@username`" do
        it "returns topics created by the specified user" do
          expect(filtered("created-by:@#{user.username}")).to contain_exactly(
            topic_by_user.id,
            topic2_by_user.id,
          )
        end
      end

      describe "when query string is `created-by:@username created-by:@username2`" do
        it "returns topics created by either specified user" do
          expect(
            filtered("created-by:@#{user.username} created-by:@#{user2.username}"),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id, topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:@username,invalid`" do
        it "returns only topics created by the user with a valid username" do
          expect(filtered("created-by:@#{user.username},invalid")).to contain_exactly(
            topic_by_user.id,
            topic2_by_user.id,
          )
        end
      end

      describe "when query string is `created-by:@username,@username2`" do
        it "returns topics created by any valid specified user" do
          expect(filtered("created-by:@#{user.username},@#{user2.username}")).to contain_exactly(
            topic_by_user.id,
            topic2_by_user.id,
            topic_by_user2.id,
          )
        end
      end

      describe "when query string is `created-by:@invalid`" do
        it "returns no topics" do
          expect(filtered("created-by:@invalid")).to eq([])
        end
      end

      describe "when query string is `created-by:me`" do
        it "returns topics created by the current user" do
          expect(filtered("created-by:me", Guardian.new(user))).to contain_exactly(
            topic_by_user.id,
            topic2_by_user.id,
          )
        end

        it "returns no topics when there is no current user" do
          expect(filtered("created-by:me")).to eq([])
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

      it "returns topics created by members of the given groups, ignoring unknown names" do
        expect(filtered("created-by:group1")).to contain_exactly(
          topic_by_group1_user.id,
          topic_by_both_groups_user.id,
        )

        expect(filtered("created-by:group1,group2")).to contain_exactly(
          topic_by_group1_user.id,
          topic_by_group2_user.id,
          topic_by_both_groups_user.id,
        )

        expect(filtered("created-by:group1,invalid")).to contain_exactly(
          topic_by_group1_user.id,
          topic_by_both_groups_user.id,
        )

        expect(filtered("created-by:invalid")).to eq([])
      end

      it "orders by an expression while filtering by the creator's group" do
        expect(filtered("created-by:group1 order:title")).to contain_exactly(
          topic_by_group1_user.id,
          topic_by_both_groups_user.id,
        )
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
        it "returns no topics when the user cannot see the group" do
          expect(filtered("created-by:#{private_group.name}")).to eq([])
        end

        it "returns topics when the user belongs to the private group" do
          private_group.add(user)

          expect(
            filtered("created-by:#{private_group.name}", Guardian.new(user)),
          ).to contain_exactly(topic_by_private_group_user.id)
        end

        it "does not filter topics when user cannot see members of the group" do
          expect(
            filtered(
              "created-by:#{super_private_group.name}",
              Guardian.new(user_in_super_private_group),
            ),
          ).to eq([])
        end

        it "returns topics when user can see group members" do
          expect(
            filtered(
              "created-by:#{super_private_group.name}",
              Guardian.new(owner_of_super_private_group),
            ),
          ).to contain_exactly(
            topic_by_super_private_group_owner.id,
            topic_by_super_private_group_user.id,
          )
        end
      end
    end

    shared_examples "filtering for topics by counts" do |filter|
      it "filters by #{filter} min/max, keeping the last of duplicates and ignoring invalid values" do
        all = [topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id]

        expect(filtered("#{filter}-min:1")).to contain_exactly(*all)
        expect(filtered("#{filter}-min:3")).to contain_exactly(topic_with_3_count.id)
        expect(filtered("#{filter}-max:1")).to contain_exactly(topic_with_1_count.id)
        expect(filtered("#{filter}-min:1 #{filter}-max:2")).to contain_exactly(
          topic_with_1_count.id,
          topic_with_2_count.id,
        )
        expect(
          filtered("#{filter}-min:3 #{filter}-min:2 #{filter}-max:1 #{filter}-max:3"),
        ).to contain_exactly(topic_with_2_count.id, topic_with_3_count.id)
        expect(filtered("#{filter}-min:invalid #{filter}-max:invalid")).to contain_exactly(*all)
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

    shared_examples "filtering for topics by date column" do |filter, column|
      fab!(:topic) { Fabricate(:topic, column => Time.zone.local(2022, 1, 1)) }
      fab!(:topic2) { Fabricate(:topic, column => Time.zone.local(2023, 5, 12)) }

      it "filters #{filter} by absolute date, tolerating unpadded and invalid values" do
        expect(filtered("#{filter}-after:2022-01-01")).to contain_exactly(topic.id, topic2.id)
        expect(filtered("#{filter}-after:2023-01-1")).to contain_exactly(topic2.id)
        expect(filtered("#{filter}-after:2023-6-01")).to eq([])
        expect(filtered("#{filter}-before:2023-1-1")).to contain_exactly(topic.id)
        expect(filtered("#{filter}-before:2000-01-01")).to eq([])
        expect(filtered("#{filter}-after:invalid-date-test")).to contain_exactly(
          topic.id,
          topic2.id,
        )
      end

      it "filters #{filter} by number of days ago" do
        freeze_time do
          old_topic = Fabricate(:topic, column => 2.days.ago)
          recent_topic = Fabricate(:topic, column => Time.zone.now)

          expect(filtered("#{filter}-after:1")).to contain_exactly(recent_topic.id)
          expect(filtered("#{filter}-after:0")).to contain_exactly(recent_topic.id)
          expect(filtered("#{filter}-before:1")).to include(old_topic.id)
          expect(filtered("#{filter}-before:1")).not_to include(recent_topic.id)
        end
      end
    end

    it_behaves_like "filtering for topics by date column", "activity", :bumped_at
    it_behaves_like "filtering for topics by date column", "created", :created_at
    it_behaves_like "filtering for topics by date column", "latest-post", :last_posted_at

    describe "when filtering by bookmark date of topics" do
      fab!(:topic_1, :topic)
      fab!(:topic_2, :topic)
      fab!(:topic_3, :topic)

      it "returns no topics for anonymous users" do
        expect(filtered("bookmarked-after:2023-01-01")).to eq([])
      end

      it "filters topics by bookmark date, including a closed range" do
        freeze_time Time.zone.local(2024, 1, 15)

        Fabricate(:bookmark, user:, bookmarkable: topic_1).update_column(
          :created_at,
          Time.zone.local(2023, 6, 1),
        )
        Fabricate(:bookmark, user:, bookmarkable: topic_2).update_column(
          :created_at,
          Time.zone.local(2022, 6, 1),
        )
        Fabricate(:bookmark, user:, bookmarkable: topic_3).update_column(
          :created_at,
          Time.zone.local(2024, 1, 1),
        )

        expect(filtered("bookmarked-after:2023-01-01", user.guardian)).to contain_exactly(
          topic_1.id,
          topic_3.id,
        )
        expect(filtered("bookmarked-before:2023-01-01", user.guardian)).to contain_exactly(
          topic_2.id,
        )
        expect(
          filtered("bookmarked-after:2023-01-01 bookmarked-before:2023-12-31", user.guardian),
        ).to contain_exactly(topic_1.id)
      end

      it "supports integer days-ago format" do
        freeze_time do
          bookmark1 = Fabricate(:bookmark, user: user, bookmarkable: topic_1)
          bookmark1.update_column(:created_at, Time.zone.now)

          bookmark2 = Fabricate(:bookmark, user: user, bookmarkable: topic_2)
          bookmark2.update_column(:created_at, 3.days.ago)

          expect(filtered("bookmarked-after:1", user.guardian)).to contain_exactly(topic_1.id)

          expect(
            TopicsFilter
              .new(guardian: user.guardian)
              .filter_from_query_string("bookmarked-before:1")
              .where(id: [topic_1.id, topic_2.id])
              .pluck(:id),
          ).to contain_exactly(topic_2.id)
        end
      end

      it "includes post bookmarks" do
        freeze_time Time.zone.local(2024, 1, 15)

        post = Fabricate(:post, topic: topic_1)
        bookmark = Fabricate(:bookmark, user: user, bookmarkable: post)
        bookmark.update_column(:created_at, Time.zone.local(2023, 6, 1))

        expect(filtered("bookmarked-after:2023-01-01", user.guardian)).to contain_exactly(
          topic_1.id,
        )
      end

      it "does not return deleted topics even if they are bookmarked" do
        freeze_time Time.zone.local(2024, 1, 15)

        bookmark = Fabricate(:bookmark, user: user, bookmarkable: topic_1)
        bookmark.update_column(:created_at, Time.zone.local(2023, 6, 1))
        topic_1.destroy

        expect(filtered("bookmarked-after:2023-01-01", user.guardian)).to eq([])
      end

      it "does not return topics if their posts are deleted even if they are bookmarked" do
        freeze_time Time.zone.local(2024, 1, 15)

        post = Fabricate(:post, topic: topic_1)
        bookmark = Fabricate(:bookmark, user: user, bookmarkable: post)
        bookmark.update_column(:created_at, Time.zone.local(2023, 6, 1))
        post.destroy

        expect(filtered("bookmarked-after:2023-01-01", user.guardian)).to eq([])
      end

      it "does not include other users' bookmarks" do
        freeze_time Time.zone.local(2024, 1, 15)

        other_user = Fabricate(:user)
        bookmark = Fabricate(:bookmark, user: other_user, bookmarkable: topic_1)
        bookmark.update_column(:created_at, Time.zone.local(2023, 6, 1))

        expect(filtered("bookmarked-after:2023-01-01", user.guardian)).to eq([])
      end

      it "ignores invalid date values" do
        expect(filtered("bookmarked-after:invalid-date", user.guardian)).to include(
          topic_1.id,
          topic_2.id,
          topic_3.id,
        )
      end
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
        it "orders topics by #{order_description}, honouring -asc and ignoring an invalid suffix" do
          expect(filtered("order:#{order}")).to eq([topic2.id, topic.id, topic3.id])
          expect(filtered("order:#{order}-asc")).to eq([topic3.id, topic.id, topic2.id])
          expect(filtered("order:#{order}-invalid")).to contain_exactly(*Topic.all.pluck(:id))
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

      describe "when ordering topics by number of posts" do
        fab!(:topic) { Fabricate(:topic, posts_count: 2) }
        fab!(:topic2) { Fabricate(:topic, posts_count: 3) }
        fab!(:topic3) { Fabricate(:topic, posts_count: 1) }

        include_examples "ordering topics filters", "posts", "number of posts"
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
          it "orders topics by last visit descending for logged-in users" do
            expect(filtered("order:read", Guardian.new(user))).to eq(
              [topic2.id, topic.id, topic3.id],
            )
          end

          it "does not apply special ordering for anonymous users" do
            topics =
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:read")
                .where(id: [topic.id, topic2.id, topic3.id])

            expect(topics.pluck(:id)).to contain_exactly(topic.id, topic2.id, topic3.id)
          end
        end

        describe "when query string is `order:read-asc`" do
          it "orders topics by last visit ascending for logged-in users" do
            expect(filtered("order:read-asc", Guardian.new(user))).to eq(
              [topic3.id, topic.id, topic2.id],
            )
          end
        end
      end

      describe "composing multiple order filters" do
        fab!(:topic) { Fabricate(:topic, created_at: Time.zone.local(2023, 1, 1), views: 2) }
        fab!(:topic2) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 2) }
        fab!(:topic3) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 1) }

        describe "when query string is `order:created,views`" do
          it "orders topics by creation date and view count descending" do
            expect(filtered("order:created,views")).to eq([topic2.id, topic3.id, topic.id])
          end
        end

        describe "when query string is `order:created order:views`" do
          it "uses creation date and view count as descending tie-breakers" do
            expect(filtered("order:created order:views")).to eq([topic2.id, topic3.id, topic.id])
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
            expect(filtered("order:bumped-asc")).to eq([earlier_topic.id, now_topic.id])
          end

          it "applies default order correctly" do
            expect(filtered("order:bumped")).to eq([now_topic.id, earlier_topic.id])
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
        expect(filtered("foo:bar")).to be_empty

        expect(filtered("foo:bar", Guardian.new(admin))).to contain_exactly(topic.id)
      end
    end
  end

  describe "custom in: filter mappings" do
    fab!(:topic)
    fab!(:solved_topic) { Fabricate(:topic, closed: true) }

    around do |example|
      registered = DiscoursePluginRegistry._raw_custom_filter_mappings.dup

      Plugin::Instance.new.add_filter_custom_filter(
        "in:solved",
        &->(scope, value, guardian) { scope.where(closed: true) }
      )

      example.run
    ensure
      DiscoursePluginRegistry._raw_custom_filter_mappings.replace(registered)
    end

    it "applies a custom in: value" do
      expect(filtered("in:solved", Guardian.new(user))).to contain_exactly(solved_topic.id)
    end

    it "combines a custom in: value with a built-in one" do
      [topic, solved_topic].each do |t|
        TopicUser.change(
          user.id,
          t.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
      end

      expect(filtered("in:watching,solved", Guardian.new(user))).to contain_exactly(solved_topic.id)
    end
  end
end
