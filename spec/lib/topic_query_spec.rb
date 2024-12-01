# frozen_string_literal: true

require "topic_view"

RSpec.describe TopicQuery do
  # TODO:
  #   This fab! here has impact on all tests.
  #
  #   It happens first, but is not obvious later in the tests that we depend on
  #   the user being created so early otherwise finding new topics does not
  #   work.
  #
  #   We should use be more explicit in communicating how the clock moves
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:creator) { Fabricate(:user, refresh_auto_groups: true) }
  let(:topic_query) { TopicQuery.new(user) }

  fab!(:tl4_user) { Fabricate(:trust_level_4) }
  fab!(:moderator)
  fab!(:admin)

  describe "secure category" do
    it "filters categories out correctly" do
      category = Fabricate(:category_with_definition)
      group = Fabricate(:group)
      category.set_permissions(group => :full)
      category.save

      Fabricate(:topic, category: category)
      Fabricate(:topic, visible: false)

      expect(TopicQuery.new(nil).list_latest.topics.count).to eq(0)
      expect(TopicQuery.new(user).list_latest.topics.count).to eq(0)

      expect(Topic.top_viewed(10).count).to eq(0)
      expect(Topic.recent(10).count).to eq(0)

      # mods can see hidden topics
      expect(TopicQuery.new(moderator).list_latest.topics.count).to eq(1)
      # admins can see all the topics
      expect(TopicQuery.new(admin).list_latest.topics.count).to eq(3)

      group.add(user)
      group.save

      expect(TopicQuery.new(user).list_latest.topics.count).to eq(2)
    end
  end

  describe "custom filters" do
    it "allows custom filters to be applied" do
      topic1 = Fabricate(:topic)
      _topic2 = Fabricate(:topic)

      TopicQuery.add_custom_filter(:only_topic_id) do |results, topic_query|
        results = results.where("topics.id = ?", topic_query.options[:only_topic_id])
      end

      expect(TopicQuery.new(nil, only_topic_id: topic1.id).list_latest.topics.map(&:id)).to eq(
        [topic1.id],
      )

      TopicQuery.remove_custom_filter(:only_topic_id)
    end
  end

  describe "#list_topics_by" do
    it "allows users to view their own invisible topics" do
      _topic = Fabricate(:topic, user: user)
      _invisible_topic = Fabricate(:topic, user: user, visible: false)

      expect(TopicQuery.new(nil).list_topics_by(user).topics.count).to eq(1)
      expect(TopicQuery.new(user).list_topics_by(user).topics.count).to eq(2)
    end
  end

  describe "#list_hot" do
    it "keeps pinned topics on top" do
      pinned_topic =
        Fabricate(
          :topic,
          created_at: 1.hour.ago,
          pinned_at: 1.hour.ago,
          pinned_globally: true,
          like_count: 1,
        )
      _topic = Fabricate(:topic, created_at: 5.minute.ago, like_count: 100)
      topic = Fabricate(:topic, created_at: 1.minute.ago, like_count: 100)

      # pinned topic is older so generally it would not hit the batch without
      # extra special logic
      TopicHotScore.update_scores(2)

      expect(TopicQuery.new(nil).list_hot.topics.map(&:id)).to eq([pinned_topic.id, topic.id])

      SiteSetting.tagging_enabled = true
      user = Fabricate(:user)
      tag = Fabricate(:tag)

      TagUser.create!(
        user_id: user.id,
        tag_id: tag.id,
        notification_level: NotificationLevels.all[:muted],
      )

      topic.update!(tags: [tag])

      # even though it is muted, we should still show it cause we are filtered to it
      expect(TopicQuery.new(user, { tags: [tag.name] }).list_hot.topics.map(&:id)).to eq([topic.id])
    end

    it "excludes muted categories and topics" do
      muted_category = Fabricate(:category)
      muted_topic = Fabricate(:topic, category: muted_category)

      TopicHotScore.create!(topic_id: muted_topic.id, score: 1.0)

      expect(TopicQuery.new(user).list_hot.topics.map(&:id)).to include(muted_topic.id)

      tu =
        TopicUser.create!(
          user_id: user.id,
          topic_id: muted_topic.id,
          notification_level: TopicUser.notification_levels[:muted],
        )

      expect(TopicQuery.new(user).list_hot.topics.map(&:id)).not_to include(muted_topic.id)

      tu.destroy!

      CategoryUser.create!(
        user_id: user.id,
        category_id: muted_category.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )

      expect(TopicQuery.new(user).list_hot.topics.map(&:id)).not_to include(muted_topic.id)
    end
  end

  describe "#prioritize_pinned_topics" do
    it "does the pagination correctly" do
      num_topics = 15
      per_page = 3

      topics = []
      (num_topics - 1)
        .downto(0)
        .each { |i| topics[i] = freeze_time(i.seconds.ago) { Fabricate(:topic) } }

      topic_query = TopicQuery.new(user)
      results = topic_query.send(:default_results)

      expect(topic_query.prioritize_pinned_topics(results, per_page: per_page, page: 0)).to eq(
        topics[0...per_page],
      )

      expect(topic_query.prioritize_pinned_topics(results, per_page: per_page, page: 1)).to eq(
        topics[per_page...num_topics],
      )
    end

    it "orders globally pinned topics by pinned_at rather than bumped_at" do
      pinned1 =
        Fabricate(
          :topic,
          bumped_at: 3.hour.ago,
          pinned_at: 1.hours.ago,
          pinned_until: 10.days.from_now,
          pinned_globally: true,
        )
      pinned2 =
        Fabricate(
          :topic,
          bumped_at: 2.hour.ago,
          pinned_at: 4.hours.ago,
          pinned_until: 10.days.from_now,
          pinned_globally: true,
        )
      unpinned1 = Fabricate(:topic, bumped_at: 2.hour.ago)
      unpinned2 = Fabricate(:topic, bumped_at: 3.hour.ago)

      topic_query = TopicQuery.new(user)
      results = topic_query.send(:default_results)

      expected_order = [pinned1, pinned2, unpinned1, unpinned2].map(&:id)
      expect(topic_query.prioritize_pinned_topics(results, per_page: 10, page: 0).pluck(:id)).to eq(
        expected_order,
      )
    end

    it "orders pinned topics within a category by pinned_at rather than bumped_at" do
      cat = Fabricate(:category)
      pinned1 =
        Fabricate(
          :topic,
          category: cat,
          bumped_at: 3.hour.ago,
          pinned_at: 1.hours.ago,
          pinned_until: 10.days.from_now,
        )
      pinned2 =
        Fabricate(
          :topic,
          category: cat,
          bumped_at: 2.hour.ago,
          pinned_at: 4.hours.ago,
          pinned_until: 10.days.from_now,
        )
      unpinned1 = Fabricate(:topic, category: cat, bumped_at: 2.hour.ago)
      unpinned2 = Fabricate(:topic, category: cat, bumped_at: 3.hour.ago)

      topic_query = TopicQuery.new(user)
      results = topic_query.send(:default_results)

      expected_order = [pinned1, pinned2, unpinned1, unpinned2].map(&:id)
      expect(
        topic_query.prioritize_pinned_topics(
          results,
          per_page: 10,
          page: 0,
          category_id: cat.id,
        ).pluck(:id),
      ).to eq(expected_order)
    end
  end

  describe "tracked" do
    it "filters tracked topics correctly" do
      SiteSetting.tagging_enabled = true

      tag = Fabricate(:tag)
      topic = Fabricate(:topic, tags: [tag])
      topic2 = Fabricate(:topic)

      query = TopicQuery.new(user, filter: "tracked").list_latest
      expect(query.topics.length).to eq(0)

      TagUser.create!(
        tag_id: tag.id,
        user_id: user.id,
        notification_level: NotificationLevels.all[:watching],
      )

      cu =
        CategoryUser.create!(
          category_id: topic2.category_id,
          user_id: user.id,
          notification_level: NotificationLevels.all[:regular],
        )

      query = TopicQuery.new(user, filter: "tracked").list_latest

      expect(query.topics.map(&:id)).to contain_exactly(topic.id)

      cu.update!(notification_level: NotificationLevels.all[:tracking])

      query = TopicQuery.new(user, filter: "tracked").list_latest

      expect(query.topics.map(&:id)).to contain_exactly(topic.id, topic2.id)

      # includes subcategories of tracked categories
      parent_category = Fabricate(:category)
      sub_category = Fabricate(:category, parent_category_id: parent_category.id)
      topic3 = Fabricate(:topic, category_id: sub_category.id)

      parent_category_2 = Fabricate(:category)
      sub_category_2 = Fabricate(:category, parent_category: parent_category_2)
      topic4 = Fabricate(:topic, category: sub_category_2)

      CategoryUser.create!(
        category_id: parent_category.id,
        user_id: user.id,
        notification_level: NotificationLevels.all[:tracking],
      )

      CategoryUser.create!(
        category_id: sub_category_2.id,
        user_id: user.id,
        notification_level: NotificationLevels.all[:tracking],
      )

      query = TopicQuery.new(user, filter: "tracked").list_latest

      expect(query.topics.map(&:id)).to contain_exactly(topic.id, topic2.id, topic3.id, topic4.id)

      # includes sub-subcategories of tracked categories
      SiteSetting.max_category_nesting = 3
      sub_sub_category = Fabricate(:category, parent_category_id: sub_category.id)
      topic5 = Fabricate(:topic, category_id: sub_sub_category.id)

      query = TopicQuery.new(user, filter: "tracked").list_latest

      expect(query.topics.map(&:id)).to contain_exactly(
        topic.id,
        topic2.id,
        topic3.id,
        topic4.id,
        topic5.id,
      )
    end
  end

  describe "deleted filter" do
    it "filters deleted topics correctly" do
      SiteSetting.enable_category_group_moderation = true
      group_moderator = Fabricate(:user)
      group = Fabricate(:group)
      group.add(group_moderator)
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)
      _topic = Fabricate(:topic, category: category, deleted_at: 1.year.ago)

      expect(TopicQuery.new(admin, status: "deleted").list_latest.topics.size).to eq(1)
      expect(TopicQuery.new(moderator, status: "deleted").list_latest.topics.size).to eq(1)
      expect(
        TopicQuery
          .new(group_moderator, status: "deleted", category: category.id)
          .list_latest
          .topics
          .size,
      ).to eq(1)
      expect(TopicQuery.new(user, status: "deleted").list_latest.topics.size).to eq(0)
      expect(TopicQuery.new(nil, status: "deleted").list_latest.topics.size).to eq(0)
    end
  end

  describe "include_pms option" do
    it "includes users own pms in regular topic lists" do
      topic = Fabricate(:topic)
      own_pm = Fabricate(:private_message_topic, user: user)
      _other_pm = Fabricate(:private_message_topic, user: Fabricate(:user))

      expect(TopicQuery.new(user).list_latest.topics).to contain_exactly(topic)
      expect(TopicQuery.new(admin).list_latest.topics).to contain_exactly(topic)
      expect(TopicQuery.new(user, include_pms: true).list_latest.topics).to contain_exactly(
        topic,
        own_pm,
      )
    end
  end

  describe "include_all_pms option" do
    it "includes all pms in regular topic lists for admins" do
      topic = Fabricate(:topic)
      own_pm = Fabricate(:private_message_topic, user: user)
      other_pm = Fabricate(:private_message_topic, user: Fabricate(:user))

      expect(TopicQuery.new(user).list_latest.topics).to contain_exactly(topic)
      expect(TopicQuery.new(admin).list_latest.topics).to contain_exactly(topic)
      expect(TopicQuery.new(user, include_all_pms: true).list_latest.topics).to contain_exactly(
        topic,
        own_pm,
      )
      expect(TopicQuery.new(admin, include_all_pms: true).list_latest.topics).to contain_exactly(
        topic,
        own_pm,
        other_pm,
      )
    end
  end

  describe "category filter" do
    let(:category) { Fabricate(:category_with_definition) }
    let(:diff_category) { Fabricate(:category_with_definition, name: "Different Category") }

    it "returns topics in the category when we filter to it" do
      expect(TopicQuery.new(moderator).list_latest.topics.size).to eq(0)

      # Filter by slug
      expect(TopicQuery.new(moderator, category: category.slug).list_latest.topics.size).to eq(1)
      expect(
        TopicQuery.new(moderator, category: "#{category.id}-category").list_latest.topics.size,
      ).to eq(1)

      list = TopicQuery.new(moderator, category: diff_category.slug).list_latest
      expect(list.topics.size).to eq(1)
      expect(list.preload_key).to eq("topic_list")

      # Defaults to no category filter when slug does not exist
      expect(TopicQuery.new(moderator, category: "made up slug").list_latest.topics.size).to eq(2)
    end

    context "with subcategories" do
      let!(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
      let(:subsubcategory) do
        Fabricate(:category_with_definition, parent_category_id: subcategory.id)
      end

      # Not used in assertions but fabricated to ensure we're not leaking topics
      # across categories
      let!(:_category) { Fabricate(:category_with_definition) }
      let!(:_subcategory) { Fabricate(:category_with_definition, parent_category_id: _category.id) }

      it "works with subcategories" do
        expect(
          TopicQuery.new(moderator, category: category.id).list_latest.topics,
        ).to contain_exactly(category.topic)

        expect(
          TopicQuery.new(moderator, category: subcategory.id).list_latest.topics,
        ).to contain_exactly(subcategory.topic)

        expect(
          TopicQuery
            .new(moderator, category: category.id, no_subcategories: true)
            .list_latest
            .topics,
        ).to contain_exactly(category.topic)
      end

      it "shows a subcategory definition topic in its parent list with the right site setting" do
        SiteSetting.show_category_definitions_in_topic_lists = true

        expect(
          TopicQuery.new(moderator, category: category.id).list_latest.topics,
        ).to contain_exactly(category.topic, subcategory.topic)
      end

      it "works with subsubcategories" do
        SiteSetting.max_category_nesting = 3

        category_topic = Fabricate(:topic, category: category)
        subcategory_topic = Fabricate(:topic, category: subcategory)
        subsubcategory_topic = Fabricate(:topic, category: subsubcategory)

        SiteSetting.max_category_nesting = 2

        expect(
          TopicQuery.new(moderator, category: category.id).list_latest.topics,
        ).to contain_exactly(category.topic, category_topic, subcategory_topic)

        expect(
          TopicQuery.new(moderator, category: subcategory.id).list_latest.topics,
        ).to contain_exactly(subcategory.topic, subcategory_topic, subsubcategory_topic)

        expect(
          TopicQuery.new(moderator, category: subsubcategory.id).list_latest.topics,
        ).to contain_exactly(subsubcategory.topic, subsubcategory_topic)

        SiteSetting.max_category_nesting = 3

        expect(
          TopicQuery.new(moderator, category: category.id).list_latest.topics,
        ).to contain_exactly(
          category.topic,
          category_topic,
          subcategory_topic,
          subsubcategory_topic,
        )

        expect(
          TopicQuery.new(moderator, category: subcategory.id).list_latest.topics,
        ).to contain_exactly(subcategory.topic, subcategory_topic, subsubcategory_topic)

        expect(
          TopicQuery.new(moderator, category: subsubcategory.id).list_latest.topics,
        ).to contain_exactly(subsubcategory.topic, subsubcategory_topic)
      end
    end
  end

  describe "tag filter" do
    fab!(:tag)
    fab!(:other_tag) { Fabricate(:tag) }
    fab!(:uppercase_tag) { Fabricate(:tag, name: "HeLlO") }

    before { SiteSetting.tagging_enabled = true }

    context "with no category filter" do
      fab!(:tagged_topic1) { Fabricate(:topic, tags: [tag]) }
      fab!(:tagged_topic2) { Fabricate(:topic, tags: [other_tag]) }
      fab!(:tagged_topic3) { Fabricate(:topic, tags: [tag, other_tag]) }
      fab!(:tagged_topic4) { Fabricate(:topic, tags: [uppercase_tag]) }
      fab!(:no_tags_topic) { Fabricate(:topic) }
      fab!(:tag_group) do
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [other_tag.name])
      end
      let(:synonym) { Fabricate(:tag, target_tag: tag, name: "synonym") }

      it "excludes a tag if desired" do
        topics = TopicQuery.new(moderator, exclude_tag: tag.name).list_latest.topics
        expect(topics.any? { |t| t.tags.include?(tag) }).to eq(false)
      end

      it "does not exclude a tagged topic without permission" do
        topics = TopicQuery.new(user, exclude_tag: other_tag.name).list_latest.topics
        expect(topics.map(&:id)).to include(tagged_topic2.id)
      end

      it "returns topics with the tag when filtered to it" do
        expect(TopicQuery.new(moderator, tags: tag.name).list_latest.topics).to contain_exactly(
          tagged_topic1,
          tagged_topic3,
        )

        expect(TopicQuery.new(moderator, tags: [tag.id]).list_latest.topics).to contain_exactly(
          tagged_topic1,
          tagged_topic3,
        )

        expect(
          TopicQuery.new(moderator, tags: [tag.name, other_tag.name]).list_latest.topics,
        ).to contain_exactly(tagged_topic1, tagged_topic2, tagged_topic3)

        expect(
          TopicQuery.new(moderator, tags: [tag.id, other_tag.id]).list_latest.topics,
        ).to contain_exactly(tagged_topic1, tagged_topic2, tagged_topic3)

        expect(TopicQuery.new(moderator, tags: ["hElLo"]).list_latest.topics).to contain_exactly(
          tagged_topic4,
        )
      end

      it "can return topics with all specified tags" do
        expect(
          TopicQuery
            .new(moderator, tags: [tag.name, other_tag.name], match_all_tags: true)
            .list_latest
            .topics
            .map(&:id),
        ).to eq([tagged_topic3.id])
      end

      it "can return topics with tag intersections using truthy/falsey values" do
        expect(
          TopicQuery
            .new(moderator, tags: [tag.name, other_tag.name], match_all_tags: "false")
            .list_latest
            .topics
            .map(&:id)
            .sort,
        ).to eq([tagged_topic1.id, tagged_topic2.id, tagged_topic3.id].sort)
      end

      it "returns an empty relation when an invalid tag is passed" do
        expect(
          TopicQuery
            .new(moderator, tags: [tag.name, "notatag"], match_all_tags: true)
            .list_latest
            .topics,
        ).to be_empty
      end

      it "can return topics with no tags" do
        expect(TopicQuery.new(moderator, no_tags: true).list_latest.topics.map(&:id)).to eq(
          [no_tags_topic.id],
        )
      end

      it "can filter using a synonym" do
        expect(TopicQuery.new(moderator, tags: synonym.name).list_latest.topics).to contain_exactly(
          tagged_topic1,
          tagged_topic3,
        )

        expect(TopicQuery.new(moderator, tags: [synonym.id]).list_latest.topics).to contain_exactly(
          tagged_topic1,
          tagged_topic3,
        )

        expect(
          TopicQuery.new(moderator, tags: [synonym.name, other_tag.name]).list_latest.topics,
        ).to contain_exactly(tagged_topic1, tagged_topic2, tagged_topic3)

        expect(
          TopicQuery.new(moderator, tags: [synonym.id, other_tag.id]).list_latest.topics,
        ).to contain_exactly(tagged_topic1, tagged_topic2, tagged_topic3)

        expect(TopicQuery.new(moderator, tags: ["SYnonYM"]).list_latest.topics).to contain_exactly(
          tagged_topic1,
          tagged_topic3,
        )
      end

      context "with hidden tags" do
        let(:hidden_tag) { Fabricate(:tag, name: "hidden") }
        let!(:staff_tag_group) do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
        end
        let!(:topic_with_hidden_tag) { Fabricate(:topic, tags: [tag, hidden_tag]) }

        it "returns topics with hidden tag to admin" do
          expect(
            TopicQuery.new(admin, tags: hidden_tag.name).list_latest.topics,
          ).to contain_exactly(topic_with_hidden_tag)
        end

        it "doesn't return topics with hidden tags to anon" do
          expect(TopicQuery.new(nil, tags: hidden_tag.name).list_latest.topics).to be_empty
        end

        it "doesn't return topic with hidden tags to non-staff" do
          expect(TopicQuery.new(user, tags: hidden_tag.name).list_latest.topics).to be_empty
        end

        it "returns topics with hidden tag to admin when using match_all_tags" do
          expect(
            TopicQuery
              .new(admin, tags: [tag.name, hidden_tag.name], match_all_tags: true)
              .list_latest
              .topics,
          ).to contain_exactly(topic_with_hidden_tag)
        end

        it "doesn't return topic with hidden tags to non-staff when using match_all_tags" do
          expect(
            TopicQuery
              .new(user, tags: [tag.name, hidden_tag.name], match_all_tags: true)
              .list_latest
              .topics,
          ).to be_empty
        end
      end
    end

    context "when remove_muted_tags is enabled" do
      fab!(:topic) { Fabricate(:topic, tags: [tag]) }

      before do
        SiteSetting.remove_muted_tags_from_latest = "always"
        SiteSetting.default_tags_muted = tag.name
      end

      it "removes default muted tag topics for anonymous users" do
        expect(TopicQuery.new(nil).list_latest.topics.map(&:id)).not_to include(topic.id)
      end
    end

    context "with categories too" do
      let(:category1) { Fabricate(:category_with_definition) }
      let(:category2) { Fabricate(:category_with_definition) }

      it "returns topics in the given category with the given tag" do
        tagged_topic1 = Fabricate(:topic, category: category1, tags: [tag])
        _tagged_topic2 = Fabricate(:topic, category: category2, tags: [tag])
        tagged_topic3 = Fabricate(:topic, category: category1, tags: [tag, other_tag])
        _no_tags_topic = Fabricate(:topic, category: category1)

        expect(
          TopicQuery
            .new(moderator, category: category1.id, tags: [tag.name])
            .list_latest
            .topics
            .map(&:id)
            .sort,
        ).to eq([tagged_topic1.id, tagged_topic3.id].sort)
        expect(
          TopicQuery
            .new(moderator, category: category2.id, tags: [other_tag.name])
            .list_latest
            .topics
            .size,
        ).to eq(0)
      end
    end
  end

  describe "muted categories" do
    it "is removed from top, new and latest lists" do
      category = Fabricate(:category_with_definition)
      topic = Fabricate(:topic, category: category)
      CategoryUser.create!(
        user_id: user.id,
        category_id: category.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(topic_query.list_new.topics.map(&:id)).not_to include(topic.id)
      expect(topic_query.list_latest.topics.map(&:id)).not_to include(topic.id)
      TopTopic.create!(topic: topic, all_score: 1)
      expect(topic_query.list_top_for(:all).topics.map(&:id)).not_to include(topic.id)
    end
  end

  describe "#list_top_for" do
    it "lists top for the week" do
      Fabricate(:topic, like_count: 1000, posts_count: 100)
      TopTopic.refresh!
      expect(topic_query.list_top_for(:weekly).topics.count).to eq(1)
    end

    it "only allows periods defined by TopTopic.periods" do
      expect { topic_query.list_top_for(:all) }.not_to raise_error
      expect { topic_query.list_top_for(:yearly) }.not_to raise_error
      expect { topic_query.list_top_for(:quarterly) }.not_to raise_error
      expect { topic_query.list_top_for(:monthly) }.not_to raise_error
      expect { topic_query.list_top_for(:weekly) }.not_to raise_error
      expect { topic_query.list_top_for(:daily) }.not_to raise_error
      expect { topic_query.list_top_for("some bad input") }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe "mute_all_categories_by_default" do
    fab!(:category) { Fabricate(:category_with_definition) }
    fab!(:topic) { Fabricate(:topic, category: category) }

    before { SiteSetting.mute_all_categories_by_default = true }

    it "should remove all topics from new and latest lists by default" do
      expect(topic_query.list_new.topics.map(&:id)).not_to include(topic.id)
      expect(topic_query.list_latest.topics.map(&:id)).not_to include(topic.id)
    end

    it "should include tracked category topics in new and latest lists" do
      topic = Fabricate(:topic, category: category)
      CategoryUser.create!(
        user_id: user.id,
        category_id: category.id,
        notification_level: CategoryUser.notification_levels[:tracking],
      )
      expect(topic_query.list_new.topics.map(&:id)).to include(topic.id)
      expect(topic_query.list_latest.topics.map(&:id)).to include(topic.id)
    end

    it "should include default watched category topics in latest list for anonymous users" do
      SiteSetting.default_categories_watching = category.id.to_s
      expect(TopicQuery.new.list_latest.topics.map(&:id)).to include(topic.id)
    end

    it "should include default regular category topics in latest list for anonymous users" do
      SiteSetting.default_categories_normal = category.id.to_s
      expect(TopicQuery.new.list_latest.topics.map(&:id)).to include(topic.id)
    end

    it "should include topics when filtered by category" do
      topic_query = TopicQuery.new(user, category: topic.category_id)
      expect(topic_query.list_latest.topics.map(&:id)).to include(topic.id)
    end
  end

  describe "already seen topics" do
    it "is removed from new and visible on latest lists" do
      category = Fabricate(:category_with_definition)
      topic = Fabricate(:topic, category: category)
      DismissedTopicUser.create!(user_id: user.id, topic_id: topic.id, created_at: Time.zone.now)
      expect(topic_query.list_new.topics.map(&:id)).not_to include(topic.id)
      expect(topic_query.list_latest.topics.map(&:id)).to include(topic.id)
    end
  end

  describe "muted tags" do
    it "is removed from new and latest lists" do
      SiteSetting.tagging_enabled = true
      SiteSetting.remove_muted_tags_from_latest = "always"

      muted_tag, other_tag = Fabricate(:tag), Fabricate(:tag)

      muted_topic = Fabricate(:topic, tags: [muted_tag])
      tagged_topic = Fabricate(:topic, tags: [other_tag])
      muted_tagged_topic = Fabricate(:topic, tags: [muted_tag, other_tag])
      untagged_topic = Fabricate(:topic)

      TagUser.create!(
        user_id: user.id,
        tag_id: muted_tag.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )

      topic_ids = topic_query.list_latest.topics.map(&:id)
      expect(topic_ids).to contain_exactly(tagged_topic.id, untagged_topic.id)

      topic_ids = topic_query.list_new.topics.map(&:id)
      expect(topic_ids).to contain_exactly(tagged_topic.id, untagged_topic.id)

      SiteSetting.remove_muted_tags_from_latest = "only_muted"

      topic_ids = topic_query.list_latest.topics.map(&:id)
      expect(topic_ids).to contain_exactly(
        tagged_topic.id,
        muted_tagged_topic.id,
        untagged_topic.id,
      )

      topic_ids = topic_query.list_new.topics.map(&:id)
      expect(topic_ids).to contain_exactly(
        tagged_topic.id,
        muted_tagged_topic.id,
        untagged_topic.id,
      )

      SiteSetting.remove_muted_tags_from_latest = "never"

      topic_ids = topic_query.list_latest.topics.map(&:id)
      expect(topic_ids).to contain_exactly(
        muted_topic.id,
        tagged_topic.id,
        muted_tagged_topic.id,
        untagged_topic.id,
      )

      topic_ids = topic_query.list_new.topics.map(&:id)
      expect(topic_ids).to contain_exactly(
        muted_topic.id,
        tagged_topic.id,
        muted_tagged_topic.id,
        untagged_topic.id,
      )
    end

    it "is not removed from the tag page itself" do
      muted_tag = Fabricate(:tag)
      TagUser.create!(
        user_id: user.id,
        tag_id: muted_tag.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )

      muted_topic = Fabricate(:topic, tags: [muted_tag])

      topic_ids = topic_query.latest_results(tags: [muted_tag.name]).map(&:id)
      expect(topic_ids).to contain_exactly(muted_topic.id)

      muted_tag.update(name: "mixedCaseName")
      topic_ids = topic_query.latest_results(tags: [muted_tag.name.downcase]).map(&:id)
      expect(topic_ids).to contain_exactly(muted_topic.id)
    end
  end

  describe "a bunch of topics" do
    fab!(:regular_topic) do
      Fabricate(
        :topic,
        title: "this is a regular topic",
        user: creator,
        views: 100,
        like_count: 66,
        posts_count: 3,
        participant_count: 11,
        bumped_at: 15.minutes.ago,
      )
    end
    fab!(:pinned_topic) do
      Fabricate(
        :topic,
        title: "this is a pinned topic",
        user: creator,
        views: 10,
        like_count: 100,
        posts_count: 5,
        participant_count: 12,
        pinned_at: 10.minutes.ago,
        pinned_globally: true,
        bumped_at: 10.minutes.ago,
      )
    end
    fab!(:archived_topic) do
      Fabricate(
        :topic,
        title: "this is an archived topic",
        user: creator,
        views: 50,
        like_count: 30,
        posts_count: 4,
        archived: true,
        participant_count: 1,
        bumped_at: 6.minutes.ago,
      )
    end
    fab!(:invisible_topic) do
      Fabricate(
        :topic,
        title: "this is an invisible topic",
        user: creator,
        views: 1,
        like_count: 5,
        posts_count: 2,
        visible: false,
        participant_count: 3,
        bumped_at: 5.minutes.ago,
      )
    end
    fab!(:closed_topic) do
      Fabricate(
        :topic,
        title: "this is a closed topic",
        user: creator,
        views: 2,
        like_count: 1,
        posts_count: 1,
        closed: true,
        participant_count: 2,
        bumped_at: 1.minute.ago,
      )
    end
    fab!(:future_topic) do
      Fabricate(
        :topic,
        title: "this is a topic in far future",
        user: creator,
        views: 30,
        like_count: 11,
        posts_count: 6,
        participant_count: 5,
        bumped_at: 1000.years.from_now,
      )
    end

    let(:topics) { topic_query.list_latest.topics }

    context "with list_latest" do
      it "returns the topics in the correct order" do
        expect(topics.map(&:id)).to eq(
          [pinned_topic, future_topic, closed_topic, archived_topic, regular_topic].map(&:id),
        )

        # includes the invisible topic if you're a moderator
        expect(TopicQuery.new(moderator).list_latest.topics.include?(invisible_topic)).to eq(true)

        # includes the invisible topic if you're an admin
        expect(TopicQuery.new(admin).list_latest.topics.include?(invisible_topic)).to eq(true)

        # includes the invisible topic if you're a TL4 user
        expect(TopicQuery.new(tl4_user).list_latest.topics.include?(invisible_topic)).to eq(true)
      end

      context "with sort_order" do
        def ids_in_order(order, descending = true)
          TopicQuery
            .new(admin, order: order, ascending: descending ? "false" : "true")
            .list_latest
            .topics
            .map(&:id)
        end

        it "returns the topics in correct order" do
          # returns the topics in likes order if requested
          expect(ids_in_order("posts")).to eq(
            [
              future_topic,
              pinned_topic,
              archived_topic,
              regular_topic,
              invisible_topic,
              closed_topic,
            ].map(&:id),
          )

          # returns the topics in reverse likes order if requested
          expect(ids_in_order("posts", false)).to eq(
            [
              closed_topic,
              invisible_topic,
              regular_topic,
              archived_topic,
              pinned_topic,
              future_topic,
            ].map(&:id),
          )

          # returns the topics in likes order if requested
          expect(ids_in_order("likes")).to eq(
            [
              pinned_topic,
              regular_topic,
              archived_topic,
              future_topic,
              invisible_topic,
              closed_topic,
            ].map(&:id),
          )

          # returns the topics in reverse likes order if requested
          expect(ids_in_order("likes", false)).to eq(
            [
              closed_topic,
              invisible_topic,
              future_topic,
              archived_topic,
              regular_topic,
              pinned_topic,
            ].map(&:id),
          )

          # returns the topics in views order if requested
          expect(ids_in_order("views")).to eq(
            [
              regular_topic,
              archived_topic,
              future_topic,
              pinned_topic,
              closed_topic,
              invisible_topic,
            ].map(&:id),
          )

          # returns the topics in reverse views order if requested" do
          expect(ids_in_order("views", false)).to eq(
            [
              invisible_topic,
              closed_topic,
              pinned_topic,
              future_topic,
              archived_topic,
              regular_topic,
            ].map(&:id),
          )

          # returns the topics in posters order if requested" do
          expect(ids_in_order("posters")).to eq(
            [
              pinned_topic,
              regular_topic,
              future_topic,
              invisible_topic,
              closed_topic,
              archived_topic,
            ].map(&:id),
          )

          # returns the topics in reverse posters order if requested" do
          expect(ids_in_order("posters", false)).to eq(
            [
              archived_topic,
              closed_topic,
              invisible_topic,
              future_topic,
              regular_topic,
              pinned_topic,
            ].map(&:id),
          )

          # sets a custom field for each topic to emulate a plugin
          regular_topic.custom_fields["sheep"] = 26
          pinned_topic.custom_fields["sheep"] = 47
          archived_topic.custom_fields["sheep"] = 69
          invisible_topic.custom_fields["sheep"] = 12
          closed_topic.custom_fields["sheep"] = 31
          future_topic.custom_fields["sheep"] = 53

          regular_topic.save
          pinned_topic.save
          archived_topic.save
          invisible_topic.save
          closed_topic.save
          future_topic.save

          # adds the custom field as a viable sort option
          class ::TopicQuery
            SORTABLE_MAPPING["sheep"] = "custom_fields.sheep"
          end
          # returns the topics in the sheep order if requested" do
          expect(ids_in_order("sheep")).to eq(
            [
              archived_topic,
              future_topic,
              pinned_topic,
              closed_topic,
              regular_topic,
              invisible_topic,
            ].map(&:id),
          )

          # returns the topics in reverse sheep order if requested" do
          expect(ids_in_order("sheep", false)).to eq(
            [
              invisible_topic,
              regular_topic,
              closed_topic,
              pinned_topic,
              future_topic,
              archived_topic,
            ].map(&:id),
          )
        end
      end
    end

    context "after clearing a pinned topic" do
      before { pinned_topic.clear_pin_for(user) }

      it "no longer shows the pinned topic at the top" do
        expect(topics).to eq(
          [future_topic, closed_topic, archived_topic, pinned_topic, regular_topic],
        )
      end
    end
  end

  describe "categorized" do
    fab!(:category) { Fabricate(:category_with_definition) }
    let(:topic_category) { category.topic }
    fab!(:topic_no_cat) { Fabricate(:topic) }
    fab!(:topic_in_cat1) do
      Fabricate(:topic, category: category, bumped_at: 10.minutes.ago, created_at: 10.minutes.ago)
    end
    fab!(:topic_in_cat2) { Fabricate(:topic, category: category) }

    describe "#list_new_in_category" do
      it "returns the topic category and the categorized topic" do
        expect(topic_query.list_new_in_category(category).topics.map(&:id)).to eq(
          [topic_in_cat2.id, topic_category.id, topic_in_cat1.id],
        )
      end
    end

    describe "category default sort order" do
      it "can use category's default sort order" do
        category.update!(sort_order: "created", sort_ascending: true)
        topic_ids = TopicQuery.new(user, category: category.id).list_latest.topics.map(&:id)
        expect(topic_ids - [topic_category.id]).to eq([topic_in_cat1.id, topic_in_cat2.id])
      end

      it "uses the category's default sort order when filter is passed as a string" do
        category.update!(sort_order: "created", sort_ascending: true)
        topic_ids =
          TopicQuery.new(user, category: category.id, filter: "latest").list_latest.topics.map(&:id)
        expect(topic_ids - [topic_category.id]).to eq([topic_in_cat1.id, topic_in_cat2.id])
      end

      it "uses the category's default sort order when filter=default is passed explicitly" do
        category.update!(sort_order: "created", sort_ascending: true)
        topic_ids =
          TopicQuery
            .new(user, category: category.id, filter: "default")
            .list_latest
            .topics
            .map(&:id)
        expect(topic_ids - [topic_category.id]).to eq([topic_in_cat1.id, topic_in_cat2.id])
      end

      it "should apply default sort order to latest and unseen filters only" do
        category.update!(sort_order: "created", sort_ascending: true)

        topic1 =
          Fabricate(
            :topic,
            category: category,
            like_count: 1000,
            posts_count: 100,
            created_at: 1.day.ago,
          )
        topic2 =
          Fabricate(
            :topic,
            category: category,
            like_count: 5200,
            posts_count: 500,
            created_at: 1.hour.ago,
          )
        TopTopic.refresh!

        topic_ids =
          TopicQuery.new(user, category: category.id).list_top_for(:monthly).topics.map(&:id)
        expect(topic_ids).to eq([topic2.id, topic1.id])
      end

      it "ignores invalid order value" do
        category.update!(sort_order: "funny")
        topic_ids = TopicQuery.new(user, category: category.id).list_latest.topics.map(&:id)
        expect(topic_ids - [topic_category.id]).to eq([topic_in_cat2.id, topic_in_cat1.id])
      end

      it "can be overridden" do
        category.update!(sort_order: "created", sort_ascending: true)
        topic_ids =
          TopicQuery
            .new(user, category: category.id, order: "activity")
            .list_latest
            .topics
            .map(&:id)
        expect(topic_ids - [topic_category.id]).to eq([topic_in_cat2.id, topic_in_cat1.id])
      end
    end
  end

  describe "unread / read topics" do
    context "with no data" do
      it "has no unread topics" do
        expect(topic_query.list_unread.topics).to be_blank
      end
    end

    context "with whispers" do
      before { SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}" }

      it "correctly shows up in unread for staff" do
        first = create_post(raw: "this is the first post", title: "super amazing title")

        _whisper =
          create_post(
            topic_id: first.topic.id,
            post_type: Post.types[:whisper],
            raw: "this is a whispered reply",
          )

        topic_id = first.topic.id

        TopicUser.update_last_read(user, topic_id, first.post_number, 1, 1)
        TopicUser.update_last_read(admin, topic_id, first.post_number, 1, 1)

        TopicUser.change(
          user.id,
          topic_id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        TopicUser.change(
          admin.id,
          topic_id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        expect(TopicQuery.new(user).list_unread.topics).to eq([])
        expect(TopicQuery.new(admin).list_unread.topics).to eq([first.topic])
      end
    end

    context "with read data" do
      fab!(:partially_read) { Fabricate(:post, user: creator).topic }
      fab!(:fully_read) { Fabricate(:post, user: creator).topic }

      before do
        TopicUser.update_last_read(user, partially_read.id, 0, 0, 0)
        TopicUser.update_last_read(user, fully_read.id, 1, 1, 0)
      end

      context "with list_unread" do
        it "lists topics correctly" do
          _new_topic = Fabricate(:post, user: creator).topic

          expect(topic_query.list_unread.topics).to eq([])
          expect(topic_query.list_read.topics).to match_array([fully_read, partially_read])
        end
      end

      context "with user with auto_track_topics list_unread" do
        before do
          user.user_option.auto_track_topics_after_msecs = 0
          user.user_option.save
        end

        it "only contains the partially read topic" do
          expect(topic_query.list_unread.topics).to eq([partially_read])
        end
      end
    end
  end

  describe "#list_new" do
    context "without a new topic" do
      it "has no new topics" do
        expect(topic_query.list_new.topics).to be_blank
      end
    end

    context "when preloading api" do
      it "preloads data correctly" do
        TopicList.preloaded_custom_fields << "tag"
        TopicList.preloaded_custom_fields << "age"
        TopicList.preloaded_custom_fields << "foo"

        topic = Fabricate.build(:topic, user: creator, bumped_at: 10.minutes.ago)
        topic.custom_fields["tag"] = %w[a b c]
        topic.custom_fields["age"] = 22
        topic.save

        new_topic = topic_query.list_new.topics.first

        expect(new_topic.custom_fields["tag"].sort).to eq(%w[a b c])
        expect(new_topic.custom_fields["age"]).to eq("22")

        expect(new_topic.custom_field_preloaded?("tag")).to eq(true)
        expect(new_topic.custom_field_preloaded?("age")).to eq(true)
        expect(new_topic.custom_field_preloaded?("foo")).to eq(true)
        expect(new_topic.custom_field_preloaded?("bar")).to eq(false)

        TopicList.preloaded_custom_fields.clear

        # if we attempt to access non preloaded fields explode
        expect { new_topic.custom_fields["boom"] }.to raise_error(StandardError)
      end
    end

    context "when preloading associations" do
      it "preloads associations" do
        DiscoursePluginRegistry.register_topic_preloader_association(
          :first_post,
          Plugin::Instance.new,
        )

        topic = Fabricate(:topic)
        Fabricate(:post, topic: topic)

        new_topic = topic_query.list_new.topics.first
        expect(new_topic.association(:image_upload).loaded?).to eq(true) # Preloaded by default
        expect(new_topic.association(:first_post).loaded?).to eq(true) # Testing a user-defined preloaded association
        expect(new_topic.association(:user).loaded?).to eq(false) # Testing the negative

        DiscoursePluginRegistry.reset_register!(:topic_preloader_associations)
      end
    end

    context "with a new topic" do
      let!(:new_topic) { Fabricate(:topic, user: creator, bumped_at: 10.minutes.ago) }
      let(:topics) { topic_query.list_new.topics }

      it "contains no new topics for a user that has missed the window" do
        expect(topic_query.list_new.topics).to eq([new_topic])

        user.user_option.new_topic_duration_minutes = 5
        user.user_option.save
        new_topic.created_at = 10.minutes.ago
        new_topic.save
        expect(topic_query.list_new.topics).to eq([])
      end

      context "with muted topics" do
        before { new_topic.notify_muted!(user) }

        it "returns an empty set" do
          expect(topics).to be_blank
          expect(topic_query.list_latest.topics).to be_blank
        end

        context "when un-muted" do
          before { new_topic.notify_tracking!(user) }

          it "returns the topic again" do
            expect(topics).to eq([new_topic])
            expect(topic_query.list_latest.topics).not_to be_blank
          end
        end
      end
    end
  end

  describe "#list_posted" do
    let(:topics) { topic_query.list_posted.topics }

    it "returns blank when there are no posted topics" do
      expect(topics).to be_blank
    end

    context "with created topics" do
      let!(:created_topic) { create_post(user: user).topic }

      it "includes the created topic" do
        expect(topics.include?(created_topic)).to eq(true)
      end
    end

    context "with topic you've posted in" do
      let(:other_users_topic) { create_post(user: creator).topic }
      let!(:your_post) { create_post(user: user, topic: other_users_topic) }

      it "includes the posted topic" do
        expect(topics.include?(other_users_topic)).to eq(true)
      end
    end

    context "with topic you haven't posted in" do
      let(:other_users_topic) { create_post(user: creator).topic }

      it "does not include the topic" do
        expect(topics).to be_blank
      end

      context "with topic you interacted with" do
        it "is not included if read" do
          TopicUser.update_last_read(user, other_users_topic.id, 0, 0, 0)

          expect(topics).to be_blank
        end

        it "is not included if muted" do
          other_users_topic.notify_muted!(user)

          expect(topics).to be_blank
        end

        it "is not included if tracking" do
          other_users_topic.notify_tracking!(user)

          expect(topics).to be_blank
        end
      end
    end
  end

  describe "#list_unseen" do
    it "returns an empty list when there aren't topics" do
      expect(topic_query.list_unseen.topics).to be_blank
    end

    it "doesn't return topics that were bumped last time before user joined the forum" do
      user.first_seen_at = 10.minutes.ago
      create_topic_with_three_posts(bumped_at: 15.minutes.ago)

      expect(topic_query.list_unseen.topics).to be_blank
    end

    it "returns only topics that contain unseen posts" do
      user.first_seen_at = 10.minutes.ago
      topic_with_unseen_posts = create_topic_with_three_posts(bumped_at: 5.minutes.ago)
      read_to_post(topic_with_unseen_posts, user, 1)

      fully_read_topic = create_topic_with_three_posts(bumped_at: 5.minutes.ago)
      read_to_the_end(fully_read_topic, user)

      expect(topic_query.list_unseen.topics).to eq([topic_with_unseen_posts])
    end

    it "ignores staff posts if user is not staff" do
      user.first_seen_at = 10.minutes.ago
      topic = create_topic_with_three_posts(bumped_at: 5.minutes.ago)
      read_to_the_end(topic, user)
      create_post(topic: topic, post_type: Post.types[:whisper])

      expect(topic_query.list_unseen.topics).to be_blank
    end

    def create_topic_with_three_posts(bumped_at:)
      topic = Fabricate(:topic, bumped_at: bumped_at)
      Fabricate(:post, topic: topic)
      Fabricate(:post, topic: topic)
      Fabricate(:post, topic: topic)
      topic.highest_staff_post_number = 3
      topic.highest_post_number = 3
      topic
    end

    def read_to_post(topic, user, post_number)
      TopicUser.update_last_read(user, topic.id, post_number, 0, 0)
    end

    def read_to_the_end(topic, user)
      read_to_post topic, user, topic.highest_post_number
    end
  end

  describe "#list_related_for" do
    let(:user) { Fabricate(:user) }
    let(:sender) { Fabricate(:user) }

    let(:group_with_user) do
      group = Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone])
      group.add(user)
      group.save
      group
    end

    def create_pm(user, opts = nil)
      unless opts
        opts = user
        user = nil
      end

      create_post(opts.merge(user: user, archetype: Archetype.private_message)).topic
    end

    def read(user, topic, post_number)
      TopicUser.update_last_read(user, topic.id, post_number, post_number, 10_000)
    end

    before do
      user.change_trust_level!(4)
      sender.change_trust_level!(4)
    end

    it "returns the correct suggestions" do
      pm_to_group = create_pm(sender, target_group_names: [group_with_user.name])
      pm_to_user = create_pm(sender, target_usernames: [user.username])

      other_user = Fabricate(:user)
      other_user.change_trust_level!(1)
      old_unrelated_pm = create_pm(other_user, target_usernames: [user.username])
      read(user, old_unrelated_pm, 1)

      related_by_user_pm = create_pm(sender, target_usernames: [user.username])
      read(user, related_by_user_pm, 1)

      related_by_group_pm = create_pm(sender, target_group_names: [group_with_user.name])
      read(user, related_by_group_pm, 1)

      expect(TopicQuery.new(user).list_related_for(pm_to_group).topics.map(&:id)).to(
        eq([related_by_group_pm.id]),
      )

      expect(TopicQuery.new(user).list_related_for(pm_to_user).topics.map(&:id)).to(
        eq([related_by_user_pm.id]),
      )

      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
      expect(TopicQuery.new(user).list_related_for(pm_to_group)).to be_blank
      expect(TopicQuery.new(user).list_related_for(pm_to_user)).to be_blank
    end
  end

  describe "#list_suggested_for" do
    def clear_cache!
      Discourse.redis.keys("random_topic_cache*").each { |k| Discourse.redis.del k }
    end

    context "when anonymous" do
      let(:topic) { Fabricate(:topic) }
      let!(:new_topic) { Fabricate(:post, user: creator).topic }

      it "should return the new topic" do
        expect(TopicQuery.new.list_suggested_for(topic).topics).to eq([new_topic])
      end

      it "should return the nothing when random topics excluded" do
        expect(TopicQuery.new.list_suggested_for(topic, include_random: false).topics).to eq([])
      end
    end

    context "when anonymously browsing with invisible, closed and archived" do
      let!(:topic) { Fabricate(:topic) }
      let!(:regular_topic) { Fabricate(:post, user: creator).topic }
      let!(:closed_topic) { Fabricate(:topic, user: creator, closed: true) }
      let!(:archived_topic) { Fabricate(:topic, user: creator, archived: true) }
      let!(:invisible_topic) { Fabricate(:topic, user: creator, visible: false) }

      it "should omit the closed/archived/invisible topics from suggested" do
        expect(TopicQuery.new.list_suggested_for(topic).topics).to eq([regular_topic])
      end
    end

    context "with a custom suggested provider registered" do
      let!(:topic1) { Fabricate(:topic) }
      let!(:topic2) { Fabricate(:topic) }
      let!(:topic3) { Fabricate(:topic) }
      let!(:topic4) { Fabricate(:topic) }
      let!(:topic5) { Fabricate(:topic) }
      let!(:topic6) { Fabricate(:topic) }
      let!(:topic7) { Fabricate(:topic) }

      let(:plugin_class) do
        Class.new(Plugin::Instance) do
          attr_accessor :enabled
          def enabled?
            true
          end

          def self.custom_suggested_topics(topic, pm_params, topic_query)
            { result: Topic.order("id desc").limit(1), params: {} }
          end
        end
      end

      let(:plugin) { plugin_class.new }

      it "should return suggested defined by the custom provider" do
        DiscoursePluginRegistry.register_list_suggested_for_provider(
          plugin_class.method(:custom_suggested_topics),
          plugin,
        )

        expect(TopicQuery.new.list_suggested_for(topic1).topics).to include(Topic.last)

        DiscoursePluginRegistry.reset_register!(:list_suggested_for_providers)
      end
    end

    context "when logged in and user is part of the `experimental_new_new_view_groups` site setting groups" do
      fab!(:group)
      fab!(:topic)

      before do
        SiteSetting.experimental_new_new_view_groups = group.name
        group.add(user)
      end

      after { clear_cache! }

      context "when there are no new topics for user" do
        it "should return random topics excluding topics that are muted by user and not older than `suggested_topics_max_days_old` site setting" do
          topic2 = Fabricate(:topic, user: user)
          topic3 = Fabricate(:topic, user: user)
          _topic4 = Fabricate(:topic, user: user, created_at: 8.days.ago)
          _topic5 = Fabricate(:topic).tap { |t| TopicNotifier.new(t).mute!(user) }

          SiteSetting.suggested_topics_max_days_old = 7

          expect(topic_query.list_suggested_for(topic).topics.map(&:id)).to eq(
            [topic3.id, topic2.id],
          )
        end
      end

      context "when there are new topics for user" do
        fab!(:category)
        fab!(:category2) { Fabricate(:category) }

        fab!(:topic_in_category_that_user_created_and_has_partially_read) do
          Fabricate(:topic, user: user, category:).tap do |t|
            _first_post = Fabricate(:post, topic: t)
            second_post = Fabricate(:post, topic: t)

            TopicUser.change(
              user.id,
              t.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            TopicUser.update_last_read(user, t.id, second_post.post_number - 1, 1, 1)
          end
        end

        fab!(:topic_in_category2_that_user_created_and_has_partially_read) do
          Fabricate(:topic, user: user, category: category2).tap do |t|
            _first_post = Fabricate(:post, topic: t)
            second_post = Fabricate(:post, topic: t)

            TopicUser.change(
              user.id,
              t.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            TopicUser.update_last_read(user, t.id, second_post.post_number - 1, 1, 1)
          end
        end

        fab!(:topic_in_category_that_user_has_partially_read) do
          Fabricate(:topic, category:).tap do |t|
            _first_post = Fabricate(:post, topic: t)
            second_post = Fabricate(:post, topic: t)

            TopicUser.change(
              user.id,
              t.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            TopicUser.update_last_read(user, t.id, second_post.post_number - 1, 1, 1)
          end
        end

        fab!(:topic_in_category2_that_user_has_partially_read) do
          Fabricate(:topic, category: category2).tap do |t|
            _first_post = Fabricate(:post, topic: t)
            second_post = Fabricate(:post, topic: t)

            TopicUser.change(
              user.id,
              t.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            TopicUser.update_last_read(user, t.id, second_post.post_number - 1, 1, 1)
          end
        end

        fab!(:topic_in_category_that_user_has_not_read) { Fabricate(:topic, category:) }
        fab!(:topic_in_category2_that_user_has_not_read) { Fabricate(:topic, category: category2) }

        before { topic.update!(category:) }

        it "should return new topics for user ordered by topics that user has created first, in the same category as the topic and then topic's bumped at" do
          expect(
            topic_query.list_suggested_for(topic, include_random: false).topics.map(&:id),
          ).to eq(
            [
              topic_in_category_that_user_created_and_has_partially_read.id,
              topic_in_category2_that_user_created_and_has_partially_read.id,
              topic_in_category_that_user_has_not_read.id,
              topic_in_category_that_user_has_partially_read.id,
              topic_in_category2_that_user_has_not_read.id,
            ],
          )

          SiteSetting.suggested_topics = 6

          expect(
            topic_query.list_suggested_for(topic, include_random: false).topics.map(&:id),
          ).to eq(
            [
              topic_in_category_that_user_created_and_has_partially_read.id,
              topic_in_category2_that_user_created_and_has_partially_read.id,
              topic_in_category_that_user_has_not_read.id,
              topic_in_category_that_user_has_partially_read.id,
              topic_in_category2_that_user_has_not_read.id,
              topic_in_category2_that_user_has_partially_read.id,
            ],
          )
        end
      end
    end

    context "when logged in" do
      def suggested_for(topic)
        topic_query.list_suggested_for(topic)&.topics&.map { |t| t.id }
      end

      let(:topic) { Fabricate(:topic) }

      let(:suggested_topics) do
        tt = topic
        # lets clear cache once category is created - working around caching is hard
        clear_cache!
        suggested_for(tt)
      end

      it "should return empty results when there is nothing to find" do
        expect(suggested_topics).to be_blank
      end

      context "with random suggested" do
        let!(:new_topic) { Fabricate(:topic, created_at: 2.days.ago) }
        let!(:old_topic) { Fabricate(:topic, created_at: 3.years.ago) }

        it "respects suggested_topics_max_days_old" do
          SiteSetting.suggested_topics_max_days_old = 1365
          tt = topic

          clear_cache!
          expect(topic_query.list_suggested_for(tt).topics.length).to eq(2)

          SiteSetting.suggested_topics_max_days_old = 365
          clear_cache!

          expect(topic_query.list_suggested_for(tt).topics.length).to eq(1)
        end

        it "removes muted topics" do
          SiteSetting.suggested_topics_max_days_old = 1365
          tt = topic
          TopicNotifier.new(old_topic).mute!(user)
          clear_cache!

          topics = topic_query.list_suggested_for(tt).topics

          expect(topics.length).to eq(1)
          expect(topics).not_to include(old_topic)
        end
      end

      context "with private messages" do
        let(:group_user) { Fabricate(:user) }
        let(:group) { Fabricate(:group) }
        let(:another_group) { Fabricate(:group) }

        let!(:topic) do
          Fabricate(
            :private_message_topic,
            topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
            topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
          )
        end

        let!(:private_message) do
          Fabricate(
            :private_message_topic,
            topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
            topic_allowed_groups: [
              Fabricate.build(:topic_allowed_group, group: group),
              Fabricate.build(:topic_allowed_group, group: another_group),
            ],
          )
        end

        let!(:private_group_topic) do
          Fabricate(
            :private_message_topic,
            user: Fabricate(:user),
            topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
          )
        end

        before do
          group.add(group_user)
          another_group.add(user)
          Group.user_trust_level_change!(user.id, user.trust_level)
          Group.user_trust_level_change!(group_user.id, group_user.trust_level)
        end

        context "as user not part of group" do
          let!(:user) { Fabricate(:user) }

          it "should not return topics by the group user" do
            expect(suggested_topics).to eq([private_message.id])
          end
        end

        context "as user part of group" do
          let!(:user) { group_user }

          it "should return the group topics" do
            expect(suggested_topics).to match_array([private_group_topic.id, private_message.id])
          end

          context "when user is not in personal_message_enabled_groups" do
            before do
              SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]
            end

            it "should not return topics by the group user" do
              expect(suggested_topics).to eq(nil)
            end
          end
        end

        context "with tag filter" do
          let(:tag) { Fabricate(:tag) }
          let!(:user) { group_user }

          it "should return only tagged topics" do
            Fabricate(:topic_tag, topic: private_message, tag: tag)
            Fabricate(:topic_tag, topic: private_group_topic)

            expect(
              TopicQuery.new(user, tags: [tag.name]).list_private_messages_tag(user).topics,
            ).to eq([private_message])
          end
        end
      end

      context "with some existing topics" do
        let!(:old_partially_read) do
          topic = Fabricate(:post, user: creator).topic
          Fabricate(:post, user: creator, topic: topic)
          topic
        end

        let!(:partially_read) do
          topic = Fabricate(:post, user: creator).topic
          Fabricate(:post, user: creator, topic: topic)
          topic
        end

        let!(:new_topic) { Fabricate(:post, user: creator).topic }
        let!(:fully_read) { Fabricate(:post, user: creator).topic }
        let!(:closed_topic) { Fabricate(:topic, user: creator, closed: true) }
        let!(:archived_topic) { Fabricate(:topic, user: creator, archived: true) }
        let!(:invisible_topic) { Fabricate(:topic, user: creator, visible: false) }
        let!(:fully_read_closed) { Fabricate(:post, user: creator).topic }
        let!(:fully_read_archived) { Fabricate(:post, user: creator).topic }

        before do
          user.user_option.update!(
            auto_track_topics_after_msecs: 0,
            new_topic_duration_minutes: User::NewTopicDuration::ALWAYS,
          )

          freeze_time 3.weeks.from_now

          TopicUser.update_last_read(user, old_partially_read.id, 1, 1, 0)
          TopicUser.update_last_read(user, partially_read.id, 1, 1, 0)
          TopicUser.update_last_read(user, fully_read.id, 1, 1, 0)
          TopicUser.update_last_read(user, fully_read_closed.id, 1, 1, 0)
          TopicUser.update_last_read(user, fully_read_archived.id, 1, 1, 0)

          fully_read_closed.closed = true
          fully_read_closed.save
          fully_read_archived.archived = true
          fully_read_archived.save

          old_partially_read.update!(updated_at: 2.weeks.ago)
          partially_read.update!(updated_at: Time.now)
        end

        it "operates correctly" do
          # Note, this is a pretty slow integration test
          # it tests that suggested is returned in the expected order
          # hence we run suggested_for twice here to save on all the setup

          SiteSetting.suggested_topics = 4
          SiteSetting.suggested_topics_unread_max_days_old = 7

          expect(suggested_topics[0]).to eq(partially_read.id)
          expect(suggested_topics[1, 3]).to contain_exactly(
            new_topic.id,
            closed_topic.id,
            archived_topic.id,
          )

          expect(suggested_topics.length).to eq(4)

          SiteSetting.suggested_topics = 2
          SiteSetting.suggested_topics_unread_max_days_old = 15

          expect(suggested_for(topic)).to contain_exactly(partially_read.id, old_partially_read.id)
        end
      end
    end
  end

  describe "#list_group_topics" do
    fab!(:group)

    let(:user) do
      user = Fabricate(:user)
      group.add(user)
      user
    end

    let(:user2) do
      user = Fabricate(:user)
      group.add(user)
      user
    end

    fab!(:user3) { Fabricate(:user) }

    fab!(:private_category) { Fabricate(:private_category_with_definition, group: group) }

    let!(:private_message_topic) { Fabricate(:private_message_post, user: user).topic }
    let!(:topic1) { Fabricate(:topic, user: user) }
    let!(:topic2) { Fabricate(:topic, user: user, category: Fabricate(:category_with_definition)) }
    let!(:topic3) { Fabricate(:topic, user: user, category: private_category) }
    let!(:topic4) { Fabricate(:topic) }
    let!(:topic5) { Fabricate(:topic, user: user, visible: false) }
    let!(:topic6) { Fabricate(:topic, user: user2) }

    it "should return the right lists for anon user" do
      topics = TopicQuery.new.list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic6)
    end

    it "should return the right list for users in the same group" do
      topics = TopicQuery.new(user).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic3, topic6)

      topics = TopicQuery.new(user2).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic3, topic6)
    end

    it "should return the right list for user no in the group" do
      topics = TopicQuery.new(user3).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic6)
    end
  end

  describe "shared drafts" do
    fab!(:category) { Fabricate(:category_with_definition) }
    fab!(:shared_drafts_category) { Fabricate(:category_with_definition) }
    fab!(:topic) { Fabricate(:topic, category: shared_drafts_category) }
    fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
    fab!(:admin)
    fab!(:user)
    fab!(:group)

    before do
      shared_drafts_category.set_permissions(group => :full)
      shared_drafts_category.save
      SiteSetting.shared_drafts_category = shared_drafts_category.id
      SiteSetting.shared_drafts_allowed_groups =
        Group::AUTO_GROUPS[:trust_level_3].to_s + "|" + Group::AUTO_GROUPS[:staff].to_s
    end

    context "with destination_category_id" do
      it "doesn't allow regular users to query destination_category_id" do
        list = TopicQuery.new(user, destination_category_id: category.id).list_latest
        expect(list.topics).not_to include(topic)
      end

      it "allows staff users to query destination_category_id" do
        list = TopicQuery.new(admin, destination_category_id: category.id).list_latest
        expect(list.topics).to include(topic)
      end

      it "allow group members with enough trust level to query destination_category_id" do
        member = Fabricate(:user, trust_level: TrustLevel[3])
        group.add(member)

        list = TopicQuery.new(member, destination_category_id: category.id).list_latest

        expect(list.topics).to include(topic)
      end

      it "doesn't allow group members without enough trust level to query destination_category_id" do
        member = Fabricate(:user, trust_level: TrustLevel[2])
        group.add(member)

        list = TopicQuery.new(member, destination_category_id: category.id).list_latest

        expect(list.topics).not_to include(topic)
      end
    end

    context "with latest" do
      it "doesn't include shared topics unless filtering by category" do
        list = TopicQuery.new(moderator).list_latest
        expect(list.topics).not_to include(topic)
      end

      it "doesn't include shared draft topics for regular users" do
        group.add(user)
        SiteSetting.shared_drafts_category = nil
        list = TopicQuery.new(user).list_latest
        expect(list.topics).to include(topic)

        SiteSetting.shared_drafts_category = shared_drafts_category.id
        list = TopicQuery.new(user).list_latest
        expect(list.topics).not_to include(topic)
      end

      it "doesn't include shared draft topics for group members with access to shared drafts" do
        member = Fabricate(:user, trust_level: TrustLevel[3])
        group.add(member)

        list = TopicQuery.new(member).list_latest
        expect(list.topics).not_to include(topic)
      end
    end

    context "with unread" do
      let!(:partially_read) do
        topic = Fabricate(:topic, category: shared_drafts_category)
        Fabricate(:post, user: creator, topic: topic).topic
        TopicUser.update_last_read(admin, topic.id, 0, 0, 0)
        TopicUser.change(
          admin.id,
          topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        topic
      end

      it "does not remove topics from unread" do
        expect(TopicQuery.new(admin).list_latest.topics).not_to include(partially_read) # Check we set up the topic/category correctly
        expect(TopicQuery.new(admin).list_unread.topics).to include(partially_read)
      end
    end
  end

  describe "#new_and_unread_results" do
    fab!(:unread_topic) { Fabricate(:post).topic }
    fab!(:new_topic) { Fabricate(:post).topic }
    fab!(:read_topic) { Fabricate(:post).topic }

    before do
      unread_post = Fabricate(:post, topic: unread_topic)
      read_post = Fabricate(:post, topic: read_topic)

      TopicUser.change(
        user.id,
        unread_topic.id,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      TopicUser.change(
        user.id,
        read_topic.id,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      TopicUser.update_last_read(user, unread_topic.id, unread_post.post_number - 1, 1, 1)
      TopicUser.update_last_read(user, read_topic.id, read_post.post_number, 1, 1)
    end

    it "includes unread and new topics for the user" do
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
        new_topic.id,
      )
    end

    it "doesn't include deleted topics" do
      unread_topic.trash!
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        new_topic.id,
      )
    end

    it "doesn't include muted topics with unread posts" do
      TopicUser.change(
        user.id,
        unread_topic.id,
        notification_level: TopicUser.notification_levels[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        new_topic.id,
      )
    end

    it "doesn't include muted new topics" do
      TopicUser.change(
        user.id,
        new_topic.id,
        notification_level: TopicUser.notification_levels[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
      )
    end

    it "doesn't include new topics in muted category" do
      CategoryUser.create!(
        user_id: user.id,
        category_id: new_topic.category.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
      )
    end

    it "includes unread and tracked topics even if they're in a muted category" do
      new_topic.update!(category: Fabricate(:category))
      CategoryUser.create!(
        user_id: user.id,
        category_id: unread_topic.category.id,
        notification_level: CategoryUser.notification_levels[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
        new_topic.id,
      )
    end

    it "doesn't include new topics that have a muted tag(s)" do
      SiteSetting.tagging_enabled = true

      tag = Fabricate(:tag)
      new_topic.tags << tag
      new_topic.save!

      TagUser.create!(
        tag_id: tag.id,
        user_id: user.id,
        notification_level: NotificationLevels.all[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
      )
    end

    it "includes unread and tracked topics even if they have a muted tag(s)" do
      SiteSetting.tagging_enabled = true

      tag = Fabricate(:tag)
      unread_topic.tags << tag
      unread_topic.save!

      TagUser.create!(
        tag_id: tag.id,
        user_id: user.id,
        notification_level: NotificationLevels.all[:muted],
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
        new_topic.id,
      )
    end

    it "doesn't include topics in restricted categories that user cannot access" do
      category = Fabricate(:category_with_definition)
      group = Fabricate(:group)
      category.set_permissions(group => :full)
      category.save!

      unread_topic.update!(category: category)
      new_topic.update!(category: category)

      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to be_blank
    end

    it "doesn't include dismissed topics" do
      DismissedTopicUser.create!(
        user_id: user.id,
        topic_id: new_topic.id,
        created_at: Time.zone.now,
      )
      expect(TopicQuery.new(user).new_and_unread_results.pluck(:id)).to contain_exactly(
        unread_topic.id,
      )
    end
  end

  describe "#apply_ordering" do
    fab!(:topic1) { Fabricate(:topic, spam_count: 3, bumped_at: 3.hours.ago) }
    fab!(:topic2) { Fabricate(:topic, spam_count: 2, bumped_at: 3.minutes.ago) }
    fab!(:topic3) { Fabricate(:topic, spam_count: 3, bumped_at: 1.hour.ago) }

    let(:modifier_block) do
      Proc.new do |result, sort_column, sort_dir, options, topic_query|
        if sort_column == "spam"
          sort_column = "spam_count"
          result.order("topics.#{sort_column} #{sort_dir}, bumped_at DESC")
        end
      end
    end

    it "returns the result of topic_query_apply_ordering_result modifier" do
      plugin_instance = Plugin::Instance.new
      plugin_instance.register_modifier(:topic_query_apply_ordering_result, &modifier_block)

      topics = TopicQuery.new(nil, order: "spam", ascending: "false").list_latest.topics
      expect(topics.map(&:id)).to eq([topic3.id, topic1.id, topic2.id])
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :topic_query_apply_ordering_result,
        &modifier_block
      )
    end

    it "ignores the result of topic_query_apply_ordering_result if modifier not registered" do
      topics = TopicQuery.new(nil, order: "spam", ascending: "false").list_latest.topics
      expect(topics.map(&:id)).to eq([topic2.id, topic3.id, topic1.id])
    end
  end

  describe "show_category_definitions_in_topic_lists setting" do
    fab!(:category) { Fabricate(:category_with_definition) }
    fab!(:subcategory) { Fabricate(:category_with_definition, parent_category: category) }
    fab!(:subcategory_regular_topic) { Fabricate(:topic, category: subcategory) }

    it "excludes subcategory definition topics by default" do
      expect(
        TopicQuery.new(nil, category: category.id).list_latest.topics.map(&:id),
      ).to contain_exactly(category.topic_id, subcategory_regular_topic.id)
    end

    it "works when topic_id is null" do
      subcategory.topic.destroy!
      subcategory.update!(topic_id: nil)
      expect(
        TopicQuery.new(nil, category: category.id).list_latest.topics.map(&:id),
      ).to contain_exactly(category.topic_id, subcategory_regular_topic.id)
    end

    it "includes subcategory definition when setting enabled" do
      SiteSetting.show_category_definitions_in_topic_lists = true
      expect(
        TopicQuery.new(nil, category: category.id).list_latest.topics.map(&:id),
      ).to contain_exactly(category.topic_id, subcategory.topic_id, subcategory_regular_topic.id)
    end
  end

  describe "with topic_query_create_list_topics modifier" do
    fab!(:topic1) { Fabricate(:topic, created_at: 3.days.ago, bumped_at: 1.hour.ago) }
    fab!(:topic2) { Fabricate(:topic, created_at: 2.days.ago, bumped_at: 3.hour.ago) }

    after { DiscoursePluginRegistry.clear_modifiers! }

    it "allows changing" do
      original_topic_query = TopicQuery.new(user)

      Plugin::Instance
        .new
        .register_modifier(:topic_query_create_list_topics) do |topics, options, topic_query|
          expect(topic_query).to eq(topic_query)
          topic_query.options[:order] = "created"
          topics
        end

      expect(original_topic_query.list_latest.topics.map(&:id)).to eq([topic1, topic2].map(&:id))

      DiscoursePluginRegistry.clear_modifiers!

      expect(original_topic_query.list_latest.topics.map(&:id)).to eq([topic2, topic1].map(&:id))
    end
  end

  describe "precedence of categories and tag setting" do
    fab!(:watched_category) do
      Fabricate(:category).tap do |category|
        CategoryUser.create!(
          user: user,
          category: category,
          notification_level: CategoryUser.notification_levels[:watching],
        )
      end
    end
    fab!(:muted_category) do
      Fabricate(:category).tap do |category|
        CategoryUser.create!(
          user: user,
          category: category,
          notification_level: CategoryUser.notification_levels[:muted],
        )
      end
    end
    fab!(:watched_tag) do
      Fabricate(:tag).tap do |tag|
        TagUser.create!(
          user: user,
          tag: tag,
          notification_level: TagUser.notification_levels[:watching],
        )
      end
    end
    fab!(:muted_tag) do
      Fabricate(:tag).tap do |tag|
        TagUser.create!(
          user: user,
          tag: tag,
          notification_level: TagUser.notification_levels[:muted],
        )
      end
    end
    fab!(:topic)
    fab!(:topic_in_watched_category_and_muted_tag) do
      Fabricate(:topic, category: watched_category, tags: [muted_tag])
    end
    fab!(:topic_in_muted_category_and_watched_tag) do
      Fabricate(:topic, category: muted_category, tags: [watched_tag])
    end
    fab!(:topic_in_watched_and_muted_tag) { Fabricate(:topic, tags: [watched_tag, muted_tag]) }
    fab!(:topic_in_muted_category) { Fabricate(:topic, category: muted_category) }
    fab!(:topic_in_muted_tag) { Fabricate(:topic, tags: [muted_tag]) }

    context "when enabled" do
      it "returns topics even if category or tag is muted but another tag or category is watched" do
        SiteSetting.watched_precedence_over_muted = true
        query = TopicQuery.new(user).list_latest
        expect(query.topics.map(&:id)).to contain_exactly(
          topic.id,
          topic_in_watched_category_and_muted_tag.id,
          topic_in_muted_category_and_watched_tag.id,
        )
      end
    end

    context "when disabled" do
      it "returns topics without muted category or tag" do
        SiteSetting.watched_precedence_over_muted = false
        query = TopicQuery.new(user).list_latest
        expect(query.topics.map(&:id)).to contain_exactly(topic.id)
      end
    end

    context "when disabled but overridden by user" do
      it "returns topics even if category or tag is muted but another tag or category is watched" do
        SiteSetting.watched_precedence_over_muted = false
        user.user_option.update!(watched_precedence_over_muted: true)
        query = TopicQuery.new(user).list_latest
        expect(query.topics.map(&:id)).to contain_exactly(
          topic.id,
          topic_in_watched_category_and_muted_tag.id,
          topic_in_muted_category_and_watched_tag.id,
        )
      end
    end
  end
end
