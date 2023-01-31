# frozen_string_literal: true

RSpec.describe TagsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:regular_user) { Fabricate(:trust_level_4) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:category) { Fabricate(:category) }
  fab!(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

  before { SiteSetting.tagging_enabled = true }

  describe "#index" do
    fab!(:test_tag) { Fabricate(:tag, name: "test", description: "some description") }

    fab!(:topic_tag) do
      Fabricate(
        :tag,
        name: "topic-test",
        public_topic_count: 1,
        staff_topic_count: 1,
        pm_topic_count: 5,
      )
    end

    fab!(:pm_only_tag) do
      Fabricate(:tag, public_topic_count: 0, staff_topic_count: 0, pm_topic_count: 1)
    end

    fab!(:synonym) { Fabricate(:tag, name: "synonym", target_tag: topic_tag) }

    shared_examples "retrieves the right tags" do
      it "retrieves all tags as a staff user" do
        sign_in(admin)

        get "/tags.json"

        expect(response.status).to eq(200)

        tags = response.parsed_body["tags"]

        serialized_tag = tags.find { |t| t["id"] == test_tag.name }

        expect(serialized_tag["count"]).to eq(0)
        expect(serialized_tag["pm_count"]).to eq(nil)
        expect(serialized_tag["pm_only"]).to eq(false)

        serialized_tag = tags.find { |t| t["id"] == topic_tag.name }

        expect(serialized_tag["count"]).to eq(1)
        expect(serialized_tag["pm_count"]).to eq(nil)
        expect(serialized_tag["pm_only"]).to eq(false)
      end

      it "does not include pm_count attribute when user cannot tag PM topics even if display_personal_messages_tag_counts site setting has been enabled" do
        SiteSetting.display_personal_messages_tag_counts = true

        sign_in(admin)

        get "/tags.json"

        expect(response.status).to eq(200)

        tags = response.parsed_body["tags"]

        expect(tags[0]["name"]).to eq(test_tag.name)
        expect(tags[0]["pm_count"]).to eq(nil)

        expect(tags[1]["name"]).to eq(topic_tag.name)
        expect(tags[1]["pm_count"]).to eq(nil)
      end

      it "includes pm_count attribute when user can tag PM topics and display_personal_messages_tag_counts site setting has been enabled" do
        SiteSetting.display_personal_messages_tag_counts = true
        SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:admins]

        sign_in(admin)

        get "/tags.json"

        expect(response.status).to eq(200)

        tags = response.parsed_body["tags"]

        serialized_tag = tags.find { |t| t["id"] == test_tag.name }

        expect(serialized_tag["pm_count"]).to eq(0)
        expect(serialized_tag["pm_only"]).to eq(false)

        serialized_tag = tags.find { |t| t["id"] == topic_tag.name }

        expect(serialized_tag["pm_count"]).to eq(5)
        expect(serialized_tag["pm_only"]).to eq(false)

        serialized_tag = tags.find { |t| t["id"] == pm_only_tag.name }

        expect(serialized_tag["pm_count"]).to eq(1)
        expect(serialized_tag["pm_only"]).to eq(true)
      end

      it "only retrieve tags that have been used in public topics for non-staff user" do
        sign_in(user)

        get "/tags.json"

        expect(response.status).to eq(200)

        tags = response.parsed_body["tags"]
        expect(tags.length).to eq(1)

        expect(tags[0]["name"]).to eq(topic_tag.name)
        expect(tags[0]["count"]).to eq(1)
        expect(tags[0]["pm_count"]).to eq(nil)
      end
    end

    context "with pm_tags_allowed_for_groups" do
      fab!(:admin) { Fabricate(:admin) }
      fab!(:topic) { Fabricate(:topic, tags: [topic_tag]) }
      fab!(:pm) do
        Fabricate(
          :private_message_topic,
          tags: [test_tag],
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end

      context "when enabled" do
        before do
          SiteSetting.pm_tags_allowed_for_groups = "1|2|3"
          SiteSetting.display_personal_messages_tag_counts = true
          sign_in(admin)
        end

        it "shows topic tags and pm tags" do
          get "/tags.json"
          tags = response.parsed_body["tags"]

          serialized_tag = tags.find { |t| t["id"] == topic_tag.name }
          expect(serialized_tag["count"]).to eq(2)
          expect(serialized_tag["pm_count"]).to eq(5)

          serialized_tag = tags.find { |t| t["id"] == test_tag.name }
          expect(serialized_tag["count"]).to eq(0)
          expect(serialized_tag["pm_count"]).to eq(1)
        end
      end

      context "when disabled" do
        before do
          SiteSetting.pm_tags_allowed_for_groups = ""
          sign_in(admin)
        end

        it "hides pm tags" do
          get "/tags.json"
          tags = response.parsed_body["tags"]
          expect(tags.length).to eq(1)
          expect(tags[0]["id"]).to eq(topic_tag.name)
        end
      end
    end

    context "with tags_listed_by_group enabled" do
      before { SiteSetting.tags_listed_by_group = true }
      include_examples "retrieves the right tags"

      it "works for tags in groups" do
        tag_group = Fabricate(:tag_group, tags: [test_tag, topic_tag, synonym])
        get "/tags.json"
        expect(response.status).to eq(200)

        tags = response.parsed_body["tags"]
        expect(tags.length).to eq(0)
        group = response.parsed_body.dig("extras", "tag_groups")&.first
        expect(group).to be_present
        expect(group["tags"].length).to eq(2)
        expect(group["tags"].map { |t| t["id"] }).to contain_exactly(test_tag.name, topic_tag.name)
      end
    end

    context "with tags_listed_by_group disabled" do
      before { SiteSetting.tags_listed_by_group = false }
      include_examples "retrieves the right tags"
    end

    context "with hidden tags" do
      before { create_hidden_tags(["staff1"]) }

      it "is returned to admins" do
        sign_in(admin)
        get "/tags.json"
        expect(response.parsed_body["tags"].map { |t| t["text"] }).to include("staff1")
        expect(response.parsed_body["extras"]["categories"]).to be_empty
      end

      it "is not returned to anon" do
        get "/tags.json"
        expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
        expect(response.parsed_body["extras"]["categories"]).to be_empty
      end

      it "is not returned to regular user" do
        sign_in(user)
        get "/tags.json"
        expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
        expect(response.parsed_body["extras"]["categories"]).to be_empty
      end

      context "when restricted to a category" do
        before { category.tags = [Tag.find_by_name("staff1")] }

        it "is returned to admins" do
          sign_in(admin)
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to include("staff1")
          categories = response.parsed_body["extras"]["categories"]
          expect(categories.length).to eq(1)
          expect(categories.first["tags"].map { |t| t["text"] }).to include("staff1")
        end

        it "is not returned to anon" do
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
          expect(response.parsed_body["extras"]["categories"]).to be_empty
        end

        it "is not returned to regular user" do
          sign_in(user)
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
          expect(response.parsed_body["extras"]["categories"]).to be_empty
        end
      end

      context "when listed by group" do
        before { SiteSetting.tags_listed_by_group = true }

        it "is returned to admins" do
          sign_in(admin)
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
          tag_groups = response.parsed_body["extras"]["tag_groups"]
          expect(tag_groups.length).to eq(1)
          expect(tag_groups.first["tags"].map { |t| t["text"] }).to include("staff1")
        end

        it "is not returned to anon" do
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
          expect(response.parsed_body["extras"]["tag_groups"]).to be_empty
        end

        it "is not returned to regular user" do
          sign_in(user)
          get "/tags.json"
          expect(response.parsed_body["tags"].map { |t| t["text"] }).to_not include("staff1")
          expect(response.parsed_body["extras"]["tag_groups"]).to be_empty
        end
      end
    end
  end

  describe "#show" do
    fab!(:tag) { Fabricate(:tag, name: "test") }
    fab!(:topic_without_tags) { Fabricate(:topic) }
    fab!(:topic_with_tags) { Fabricate(:topic, tags: [tag]) }

    it "should return the right response" do
      get "/tag/test.json"

      expect(response.status).to eq(200)

      json = response.parsed_body

      topic_list = json["topic_list"]

      expect(topic_list["tags"].map { |t| t["id"] }).to contain_exactly(tag.id)
    end

    it "should handle invalid tags" do
      get "/tag/%2ftest%2f"
      expect(response.status).to eq(404)
    end

    it "should handle synonyms" do
      synonym = Fabricate(:tag, target_tag: tag)
      get "/tag/#{synonym.name}"
      expect(response.status).to eq(200)
    end

    it "does not show staff-only tags" do
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])

      get "/tag/test"
      expect(response.status).to eq(404)

      sign_in(admin)

      get "/tag/test"
      expect(response.status).to eq(200)
    end

    it "handles special tag 'none'" do
      SiteSetting.pm_tags_allowed_for_groups = "1|2|3"

      sign_in(admin)

      get "/tag/none.json"
      expect(response.parsed_body["topic_list"]["topics"].length).to eq(1)
    end

    context "with a category in the path" do
      fab!(:topic_in_category) { Fabricate(:topic, tags: [tag], category: category) }

      fab!(:topic_in_category_without_tag) { Fabricate(:topic, category: category) }

      fab!(:topic_out_of_category) { Fabricate(:topic, tags: [tag]) }

      it "should produce the topic inside the category and not the topic outside of it" do
        get "/tags/c/#{category.slug}/#{tag.name}.json"

        topic_ids = response.parsed_body["topic_list"]["topics"].map { |x| x["id"] }
        expect(topic_ids).to include(topic_in_category.id)
        expect(topic_ids).to_not include(topic_out_of_category.id)
        expect(topic_ids).to_not include(topic_in_category_without_tag.id)
      end

      it "should produce the right next topic URL" do
        get "/tags/c/#{category.slug_path.join("/")}/#{category.id}/#{tag.name}.json?per_page=1"

        expect(response.parsed_body["topic_list"]["more_topics_url"]).to start_with(
          "/tags/c/#{category.slug_path.join("/")}/#{category.id}/#{tag.name}",
        )
      end

      it "should 404 for invalid category path" do
        get "/tags/c/#{category.slug_path.join("/")}/#{category.id}/somerandomstring/#{tag.name}.json?per_page=1"

        expect(response.status).to eq(404)
      end

      it "should 404 for secure categories" do
        c = Fabricate(:private_category, group: Fabricate(:group))
        get "/tags/c/#{c.slug_path.join("/")}/#{c.id}/#{tag.name}.json"

        expect(response.status).to eq(404)
      end
    end

    context "with a subcategory in the path" do
      fab!(:topic_in_subcategory) { Fabricate(:topic, tags: [tag], category: subcategory) }

      fab!(:topic_in_subcategory_without_tag) { Fabricate(:topic, category: subcategory) }

      fab!(:topic_out_of_subcategory) { Fabricate(:topic, tags: [tag]) }

      it "should produce the topic inside the subcategory and not the topic outside of it" do
        get "/tags/c/#{category.slug}/#{subcategory.slug}/#{tag.name}.json"

        topic_ids = response.parsed_body["topic_list"]["topics"].map { |x| x["id"] }
        expect(topic_ids).to include(topic_in_subcategory.id)
        expect(topic_ids).to_not include(topic_out_of_subcategory.id)
        expect(topic_ids).to_not include(topic_in_subcategory_without_tag.id)
      end
    end
  end

  describe "#info" do
    fab!(:tag) { Fabricate(:tag, name: "test") }
    let(:synonym) { Fabricate(:tag, name: "synonym", target_tag: tag) }

    it "returns 404 if tag not found" do
      get "/tag/nope/info.json"
      expect(response.status).to eq(404)
    end

    it "can handle tag with no synonyms" do
      get "/tag/#{tag.name}/info.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("tag_info", "name")).to eq(tag.name)
      expect(response.parsed_body.dig("tag_info", "synonyms")).to be_empty
      expect(response.parsed_body.dig("tag_info", "category_ids")).to be_empty
      expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(false)
    end

    it "can handle a synonym" do
      get "/tag/#{synonym.name}/info.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("tag_info", "name")).to eq(synonym.name)
      expect(response.parsed_body.dig("tag_info", "synonyms")).to be_empty
      expect(response.parsed_body.dig("tag_info", "category_ids")).to be_empty
      expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(false)
    end

    it "can return a tag's synonyms" do
      synonym
      get "/tag/#{tag.name}/info.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("tag_info", "synonyms").map { |t| t["text"] }).to eq(
        [synonym.name],
      )
    end

    it "returns 404 if tag is staff-only" do
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])
      get "/tag/test/info.json"
      expect(response.status).to eq(404)
    end

    it "staff-only tags can be retrieved for staff user" do
      sign_in(admin)
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])
      get "/tag/test/info.json"
      expect(response.status).to eq(200)
    end

    it "can return category restrictions" do
      category.update!(tags: [tag])
      category2 = Fabricate(:category)
      tag_group = Fabricate(:tag_group, tags: [tag])
      category2.update!(tag_groups: [tag_group])
      staff_category = Fabricate(:private_category, group: Fabricate(:group), tags: [tag])
      get "/tag/#{tag.name}/info.json"
      expect(response.parsed_body.dig("tag_info", "category_ids")).to contain_exactly(
        category.id,
        category2.id,
      )
      expect(response.parsed_body["categories"]).to be_present
      expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(true)
    end

    context "when tag belongs to a tag group" do
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag]) }

      it "returns tag groups if tag groups are visible" do
        SiteSetting.tags_listed_by_group = true
        get "/tag/#{tag.name}/info.json"
        expect(response.parsed_body.dig("tag_info", "tag_group_names")).to eq([tag_group.name])
      end

      it "doesn't return tag groups if tag groups aren't visible" do
        SiteSetting.tags_listed_by_group = false
        get "/tag/#{tag.name}/info.json"
        expect(response.parsed_body["tag_info"].has_key?("tag_group_names")).to eq(false)
      end

      context "when restricted to a private category" do
        let!(:private_category) do
          Fabricate(
            :private_category,
            group: Fabricate(:group),
            tag_groups: [tag_group],
            allow_global_tags: true,
          )
        end

        it "can return categories to users who can access them" do
          sign_in(admin)
          get "/tag/#{tag.name}/info.json"
          expect(response.parsed_body.dig("tag_info", "category_ids")).to contain_exactly(
            private_category.id,
          )
          expect(response.parsed_body["categories"]).to be_present
          expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(true)
        end

        it "can indicate category restriction to users who can't access them" do
          sign_in(user)
          get "/tag/#{tag.name}/info.json"
          expect(response.parsed_body.dig("tag_info", "category_ids")).to be_empty
          expect(response.parsed_body["categories"]).to be_blank
          expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(true)
        end

        it "can indicate category restriction to anon" do
          get "/tag/#{tag.name}/info.json"
          expect(response.parsed_body.dig("tag_info", "category_ids")).to be_empty
          expect(response.parsed_body["categories"]).to be_blank
          expect(response.parsed_body.dig("tag_info", "category_restricted")).to eq(true)
        end
      end
    end
  end

  describe "#update" do
    fab!(:tag) { Fabricate(:tag) }

    before do
      tag
      sign_in(admin)
    end

    it "triggers a extensibility event" do
      event =
        DiscourseEvent
          .track_events { put "/tag/#{tag.name}.json", params: { tag: { id: "hello" } } }
          .last

      expect(event[:event_name]).to eq(:tag_updated)
      expect(event[:params].first).to eq(tag)
    end
  end

  describe "#personal_messages" do
    fab!(:personal_message) do
      Fabricate(
        :private_message_topic,
        user: regular_user,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: regular_user),
          Fabricate.build(:topic_allowed_user, user: moderator),
          Fabricate.build(:topic_allowed_user, user: admin),
        ],
      )
    end

    fab!(:tag) { Fabricate(:tag, topics: [personal_message], name: "test") }

    before { SiteSetting.pm_tags_allowed_for_groups = "1|2|3" }

    context "as a regular user" do
      it "can't see pm tags" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response.status).to eq(403)
      end
    end

    context "as an moderator" do
      before { sign_in(moderator) }

      it "can't see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response.status).to eq(404)
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{moderator.username}.json"

        expect(response.status).to eq(200)

        tag = response.parsed_body["tags"]
        expect(tag[0]["id"]).to eq("test")
      end
    end

    context "as an admin" do
      before { sign_in(admin) }

      it "can see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response.status).to eq(200)

        tag = response.parsed_body["tags"]
        expect(tag[0]["id"]).to eq("test")
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{admin.username}.json"

        expect(response.status).to eq(200)

        tag = response.parsed_body["tags"]
        expect(tag[0]["id"]).to eq("test")
      end

      it "works with usernames with a period" do
        admin.update!(username: "test.test")

        get "/tags/personal_messages/#{admin.username}.json"

        expect(response.status).to eq(200)
      end
    end
  end

  describe "#show_latest" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:other_tag) { Fabricate(:tag) }
    fab!(:third_tag) { Fabricate(:tag) }

    fab!(:single_tag_topic) { Fabricate(:topic, tags: [tag]) }
    fab!(:multi_tag_topic) { Fabricate(:topic, tags: [tag, other_tag]) }
    fab!(:all_tag_topic) { Fabricate(:topic, tags: [tag, other_tag, third_tag]) }

    context "with tagging disabled" do
      it "returns 404" do
        SiteSetting.tagging_enabled = false
        get "/tag/#{tag.name}/l/latest.json"
        expect(response.status).to eq(404)
      end
    end

    context "with tagging enabled" do
      def parse_topic_ids
        response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
      end

      it "can filter by tag" do
        get "/tag/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can render a topic list from the latest endpoint" do
        get "/tag/#{tag.name}/l/latest"
        expect(response.status).to eq(200)
        expect(response.body).to include("topic-list")
      end

      it "can filter by two tags" do
        single_tag_topic
        multi_tag_topic
        all_tag_topic

        get "/tag/#{tag.name}/l/latest.json", params: { additional_tag_ids: other_tag.name }

        expect(response.status).to eq(200)

        topic_ids = parse_topic_ids
        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by multiple tags" do
        single_tag_topic
        multi_tag_topic
        all_tag_topic

        get "/tag/#{tag.name}/l/latest.json",
            params: {
              additional_tag_ids: "#{other_tag.name}/#{third_tag.name}",
            }

        expect(response.status).to eq(200)

        topic_ids = parse_topic_ids
        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to_not include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "does not find any tags when a tag which doesn't exist is passed" do
        single_tag_topic

        get "/tag/#{tag.name}/l/latest.json", params: { additional_tag_ids: "notatag" }

        expect(response.status).to eq(200)

        topic_ids = parse_topic_ids
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by category and tag" do
        get "/tags/c/#{category.slug}/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can filter by category, sub-category, and tag" do
        get "/tags/c/#{category.slug}/#{subcategory.slug}/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can filter by category, no sub-category, and tag" do
        get "/tags/c/#{category.slug}/none/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can handle subcategories with the same name" do
        category2 = Fabricate(:category)
        subcategory2 =
          Fabricate(
            :category,
            parent_category_id: category2.id,
            name: subcategory.name,
            slug: subcategory.slug,
          )
        t = Fabricate(:topic, category_id: subcategory2.id, tags: [other_tag])
        get "/tags/c/#{category2.slug}/#{subcategory2.slug}/#{other_tag.name}/l/latest.json"

        expect(response.status).to eq(200)

        topic_ids = parse_topic_ids
        expect(topic_ids).to include(t.id)
      end

      context "when logged in" do
        before { sign_in(user) }

        it "can filter by bookmarked" do
          get "/tag/#{tag.name}/l/bookmarks.json"

          expect(response.status).to eq(200)
        end

        it "returns a 404 when tag is restricted" do
          tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])

          get "/tag/test/l/latest.json"
          expect(response.status).to eq(404)

          sign_in(admin)

          get "/tag/test/l/latest.json"
          expect(response.status).to eq(200)
        end

        context "with muted tags" do
          before do
            TagUser.create!(
              user_id: user.id,
              tag_id: tag.id,
              notification_level: CategoryUser.notification_levels[:muted],
            )
          end

          it "includes topics when filtered by muted tag" do
            single_tag_topic

            get "/tag/#{tag.name}/l/latest.json"
            expect(response.status).to eq(200)

            topic_ids = parse_topic_ids
            expect(topic_ids).to include(single_tag_topic.id)
          end

          it "includes topics when filtered by category and muted tag" do
            category = Fabricate(:category)
            single_tag_topic.update!(category: category)

            get "/tags/c/#{category.slug}/#{tag.name}/l/latest.json"
            expect(response.status).to eq(200)

            topic_ids = parse_topic_ids
            expect(topic_ids).to include(single_tag_topic.id)
          end
        end
      end
    end
  end

  describe "#show_top" do
    fab!(:tag) { Fabricate(:tag) }

    fab!(:category) { Fabricate(:category) }
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:tag_topic) { Fabricate(:topic, category: category, tags: [tag]) }
    fab!(:tag_topic2) { Fabricate(:topic, category: category, tags: [tag]) }

    before do
      SiteSetting.top_page_default_timeframe = "all"
      TopTopic.create!(topic: topic, all_score: 1)
      TopTopic.create!(topic: tag_topic, all_score: 1)
      TopTopic.create!(topic: tag_topic2, daily_score: 1)
    end

    it "can filter by tag" do
      get "/tag/#{tag.name}/l/top.json"
      expect(response.status).to eq(200)

      topic_ids = response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
      expect(topic_ids).to eq([tag_topic.id])
    end

    it "can filter by tag and period" do
      get "/tag/#{tag.name}/l/top.json?period=daily"
      expect(response.status).to eq(200)

      list = response.parsed_body["topic_list"]
      topic_ids = list["topics"].map { |topic| topic["id"] }
      expect(topic_ids).to eq([tag_topic2.id])
      expect(list["for_period"]).to eq("daily")
    end

    it "can filter by both category and tag" do
      get "/tags/c/#{category.slug}/#{category.id}/#{tag.name}/l/top.json"
      expect(response.status).to eq(200)

      topic_ids = response.parsed_body["topic_list"]["topics"].map { |topic| topic["id"] }
      expect(topic_ids).to eq([tag_topic.id])
    end

    it "raises an error if the period is not valid" do
      get "/tag/#{tag.name}/l/top.json?period=decadely"
      expect(response.status).to eq(400)
    end

    it "returns a 404 if tag is restricted" do
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])

      get "/tag/test/l/top.json"
      expect(response.status).to eq(404)

      sign_in(admin)

      get "/tag/test/l/top.json"
      expect(response.status).to eq(200)
    end
  end

  describe "#search" do
    context "with tagging disabled" do
      it "returns 404" do
        SiteSetting.tagging_enabled = false
        get "/tags/filter/search.json", params: { q: "stuff" }
        expect(response.status).to eq(404)
      end
    end

    context "with tagging enabled" do
      it "can return some tags" do
        tag_names = %w[stuff stinky stumped]
        tag_names.each { |name| Fabricate(:tag, name: name) }
        get "/tags/filter/search.json", params: { q: "stu" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq(%w[stuff stumped])
      end

      it "returns tags ordered by public_topic_count, and prioritises exact matches" do
        Fabricate(:tag, name: "tag1", public_topic_count: 10, staff_topic_count: 10)
        Fabricate(:tag, name: "tag2", public_topic_count: 100, staff_topic_count: 100)
        Fabricate(:tag, name: "tag", public_topic_count: 1, staff_topic_count: 1)

        get "/tags/filter/search.json", params: { q: "tag", limit: 2 }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }).to eq(%w[tag tag2])
      end

      context "with category restriction" do
        fab!(:yup) { Fabricate(:tag, name: "yup") }
        fab!(:category) { Fabricate(:category, tags: [yup]) }

        it "can say if given tag is not allowed" do
          nope = Fabricate(:tag, name: "nope")
          get "/tags/filter/search.json", params: { q: nope.name, categoryId: category.id }
          expect(response.status).to eq(200)
          expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq([])
          expect(response.parsed_body["forbidden"]).to be_present
          expect(response.parsed_body["forbidden_message"]).to eq(
            I18n.t("tags.forbidden.in_this_category", tag_name: nope.name),
          )
        end

        it "can say if given tag is restricted to different category" do
          category
          get "/tags/filter/search.json",
              params: {
                q: yup.name,
                categoryId: Fabricate(:category).id,
              }
          expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq([])
          expect(response.parsed_body["forbidden"]).to be_present
          expect(response.parsed_body["forbidden_message"]).to eq(
            I18n.t(
              "tags.forbidden.restricted_to",
              count: 1,
              tag_name: yup.name,
              category_names: category.name,
            ),
          )
        end

        it "can filter on category without q param" do
          nope = Fabricate(:tag, name: "nope")
          get "/tags/filter/search.json", params: { categoryId: category.id }
          expect(response.status).to eq(200)
          expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq([yup.name])
        end
      end

      context "with synonyms" do
        fab!(:tag) { Fabricate(:tag, name: "plant") }
        fab!(:synonym) { Fabricate(:tag, name: "plants", target_tag: tag) }

        it "can return synonyms" do
          get "/tags/filter/search.json", params: { q: "plant" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["results"].map { |j| j["id"] }).to contain_exactly(
            "plant",
            "plants",
          )
        end

        it "can omit synonyms" do
          get "/tags/filter/search.json", params: { q: "plant", excludeSynonyms: "true" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["results"].map { |j| j["id"] }).to contain_exactly("plant")
        end

        it "can return a message about synonyms not being allowed" do
          get "/tags/filter/search.json", params: { q: "plants", excludeSynonyms: "true" }
          expect(response.status).to eq(200)
          expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq([])
          expect(response.parsed_body["forbidden"]).to be_present
          expect(response.parsed_body["forbidden_message"]).to eq(
            I18n.t("tags.forbidden.synonym", tag_name: tag.name),
          )
        end
      end

      it "matches tags after sanitizing input" do
        yup, nope = Fabricate(:tag, name: "yup"), Fabricate(:tag, name: "nope")
        get "/tags/filter/search.json", params: { q: "N/ope" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }.sort).to eq(["nope"])
      end

      it "can return tags that are in secured categories but are allowed to be used" do
        c = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:topic, category: c, tags: [Fabricate(:tag, name: "cooltag")])
        get "/tags/filter/search.json", params: { q: "cool" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }).to eq(["cooltag"])
      end

      it "supports Chinese and Russian" do
        tag_names = %w[房地产 тема-в-разработке]
        tag_names.each { |name| Fabricate(:tag, name: name) }

        get "/tags/filter/search.json", params: { q: "房" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }).to eq(["房地产"])

        get "/tags/filter/search.json", params: { q: "тема" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |j| j["id"] }).to eq(["тема-в-разработке"])
      end

      it "can return all the results" do
        tag_group1 = Fabricate(:tag_group, tag_names: %w[common1 common2 group1tag group1tag2])
        tag_group2 = Fabricate(:tag_group, tag_names: %w[common1 common2])
        category = Fabricate(:category, tag_groups: [tag_group1])
        get "/tags/filter/search.json",
            params: {
              q: "",
              limit: 5,
              categoryId: category.id,
              filterForInput: "true",
            }

        expect(response.status).to eq(200)
        expect_same_tag_names(
          response.parsed_body["results"].map { |j| j["id"] },
          %w[common1 common2 group1tag group1tag2],
        )
      end

      it "returns error 400 for negative limit" do
        get "/tags/filter/search.json", params: { q: "", limit: -1 }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("invalid_params", message: "limit"),
        )
      end

      it "includes required tag group information" do
        tag1 = Fabricate(:tag)
        tag2 = Fabricate(:tag)

        tag_group = Fabricate(:tag_group, tags: [tag1, tag2])
        crtg = CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1)
        category = Fabricate(:category, category_required_tag_groups: [crtg])

        get "/tags/filter/search.json",
            params: {
              q: "",
              categoryId: category.id,
              filterForInput: true,
            }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |t| t["name"] }).to contain_exactly(
          tag1.name,
          tag2.name,
        )
        expect(response.parsed_body["required_tag_group"]).to eq(
          { "name" => tag_group.name, "min_count" => crtg.min_count },
        )

        get "/tags/filter/search.json",
            params: {
              q: "",
              categoryId: category.id,
              filterForInput: true,
              selected_tags: [tag1.name],
            }
        expect(response.status).to eq(200)
        expect(response.parsed_body["results"].map { |t| t["name"] }).to contain_exactly(tag2.name)
        expect(response.parsed_body["required_tag_group"]).to eq(nil)
      end
    end
  end

  describe "#destroy" do
    context "with tagging enabled" do
      before { sign_in(admin) }

      context "with an existent tag name" do
        it "deletes the tag" do
          tag = Fabricate(:tag)
          delete "/tag/#{tag.name}.json"
          expect(response.status).to eq(200)
          expect(Tag.where(id: tag.id)).to be_empty
        end
      end

      context "with a nonexistent tag name" do
        it "returns a tag not found message" do
          delete "/tag/doesntexists.json"
          expect(response).not_to be_successful
          expect(response.parsed_body["error_type"]).to eq("not_found")
        end
      end
    end
  end

  describe "#unused" do
    it "fails if you can't manage tags" do
      sign_in(user)
      get "/tags/unused.json"
      expect(response.status).to eq(403)
      delete "/tags/unused.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(admin) }

      context "with some tags" do
        let!(:tags) do
          [
            Fabricate(
              :tag,
              name: "used_publically",
              public_topic_count: 2,
              staff_topic_count: 2,
              pm_topic_count: 0,
            ),
            Fabricate(
              :tag,
              name: "used_privately",
              public_topic_count: 0,
              staff_topic_count: 0,
              pm_topic_count: 3,
            ),
            Fabricate(
              :tag,
              name: "used_everywhere",
              public_topic_count: 0,
              staff_topic_count: 0,
              pm_topic_count: 3,
            ),
            Fabricate(
              :tag,
              name: "unused1",
              public_topic_count: 0,
              staff_topic_count: 0,
              pm_topic_count: 0,
            ),
            Fabricate(
              :tag,
              name: "unused2",
              public_topic_count: 0,
              staff_topic_count: 0,
              pm_topic_count: 0,
            ),
          ]
        end

        it "returns the correct unused tags" do
          get "/tags/unused.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["tags"]).to contain_exactly("unused1", "unused2")
        end

        it "deletes the correct tags" do
          expect { delete "/tags/unused.json" }.to change { Tag.count }.by(-2) &
            change { UserHistory.count }.by(1)
          expect(Tag.pluck(:name)).to contain_exactly(
            "used_publically",
            "used_privately",
            "used_everywhere",
          )
        end
      end
    end
  end

  describe "#upload_csv" do
    it "requires you to be logged in" do
      post "/tags/upload.json"
      expect(response.status).to eq(403)
    end

    context "while logged in" do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/tags.csv") }
      let(:invalid_csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/tags_invalid.csv") }

      let(:file) { Rack::Test::UploadedFile.new(File.open(csv_file)) }

      let(:invalid_file) { Rack::Test::UploadedFile.new(File.open(invalid_csv_file)) }

      let(:filename) { "tags.csv" }

      it "fails if you can't manage tags" do
        sign_in(user)
        post "/tags/upload.json", params: { file: file, name: filename }
        expect(response.status).to eq(403)
      end

      it "allows staff to bulk upload tags" do
        sign_in(moderator)
        post "/tags/upload.json", params: { file: file, name: filename }
        expect(response.status).to eq(200)
        expect(Tag.pluck(:name)).to contain_exactly(
          "tag1",
          "capitaltag2",
          "spaced-tag",
          "tag3",
          "tag4",
        )
        expect(Tag.find_by_name("tag3").tag_groups.pluck(:name)).to contain_exactly("taggroup1")
        expect(Tag.find_by_name("tag4").tag_groups.pluck(:name)).to contain_exactly("taggroup1")
      end

      it "fails gracefully with invalid input" do
        sign_in(moderator)

        expect do
          post "/tags/upload.json", params: { file: invalid_file, name: filename }
          expect(response.status).to eq(422)
        end.not_to change { [Tag.count, TagGroup.count] }
      end
    end
  end

  describe "#create_synonyms" do
    fab!(:tag) { Fabricate(:tag) }

    it "fails if not logged in" do
      post "/tag/#{tag.name}/synonyms.json", params: { synonyms: ["synonym1"] }
      expect(response.status).to eq(403)
    end

    it "fails if not staff user" do
      sign_in(user)
      post "/tag/#{tag.name}/synonyms.json", params: { synonyms: ["synonym1"] }
      expect(response.status).to eq(403)
    end

    context "when signed in as admin" do
      before { sign_in(admin) }

      it "can make a tag a synonym of another tag" do
        tag2 = Fabricate(:tag)
        expect {
          post "/tag/#{tag.name}/synonyms.json", params: { synonyms: [tag2.name] }
        }.to_not change { Tag.count }
        expect(response.status).to eq(200)
        expect(tag2.reload.target_tag).to eq(tag)
      end

      it "can create new tags at the same time" do
        expect {
          post "/tag/#{tag.name}/synonyms.json", params: { synonyms: ["synonym"] }
        }.to change { Tag.count }.by(1)
        expect(response.status).to eq(200)
        expect(Tag.find_by_name("synonym")&.target_tag).to eq(tag)
      end

      it "can return errors" do
        tag2 = Fabricate(:tag, target_tag: tag)
        tag3 = Fabricate(:tag)
        post "/tag/#{tag3.name}/synonyms.json", params: { synonyms: [tag.name] }
        expect(response.status).to eq(200)
        expect(response.parsed_body["failed"]).to be_present
        expect(response.parsed_body.dig("failed_tags", tag.name)).to be_present
      end
    end
  end

  describe "#destroy_synonym" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:synonym) { Fabricate(:tag, target_tag: tag, name: "synonym") }
    subject { delete("/tag/#{tag.name}/synonyms/#{synonym.name}.json") }

    it "fails if not logged in" do
      subject
      expect(response.status).to eq(403)
    end

    it "fails if not staff user" do
      sign_in(user)
      subject
      expect(response.status).to eq(403)
    end

    context "when signed in as admin" do
      before { sign_in(admin) }

      it "can remove a synonym from a tag" do
        synonym2 = Fabricate(:tag, target_tag: tag, name: "synonym2")
        expect { subject }.to_not change { Tag.count }
        expect_same_tag_names(tag.reload.synonyms, [synonym2])
        expect(synonym.reload).to_not be_synonym
      end

      it "returns error if tag isn't a synonym" do
        delete "/tag/#{Fabricate(:tag).name}/synonyms/#{synonym.name}.json"
        expect(response.status).to eq(400)
        expect_same_tag_names(tag.reload.synonyms, [synonym])
      end

      it "returns error if synonym not found" do
        delete "/tag/#{Fabricate(:tag).name}/synonyms/nope.json"
        expect(response.status).to eq(404)
        expect_same_tag_names(tag.reload.synonyms, [synonym])
      end
    end
  end

  describe "#update_notifications" do
    fab!(:tag) { Fabricate(:tag) }

    before { sign_in(user) }

    it "returns 404 when tag is not found" do
      put "/tag/someinvalidtagname/notifications.json"

      expect(response.status).to eq(404)
    end

    it "updates the notification level of a tag for a user" do
      tag_user = TagUser.change(user.id, tag.id, NotificationLevels.all[:muted])

      put "/tag/#{tag.name}/notifications.json",
          params: {
            tag_notification: {
              notification_level: NotificationLevels.all[:tracking],
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["watched_tags"]).to eq([])
      expect(response.parsed_body["watching_first_post_tags"]).to eq([])
      expect(response.parsed_body["tracked_tags"]).to eq([tag.name])
      expect(response.parsed_body["muted_tags"]).to eq([])
      expect(response.parsed_body["regular_tags"]).to eq([])

      expect(tag_user.reload.notification_level).to eq(NotificationLevels.all[:tracking])
    end

    it "sets the notification level of a tag for a user" do
      expect do
        put "/tag/#{tag.name}/notifications.json",
            params: {
              tag_notification: {
                notification_level: NotificationLevels.all[:muted],
              },
            }

        expect(response.status).to eq(200)

        expect(response.parsed_body["watched_tags"]).to eq([])
        expect(response.parsed_body["watching_first_post_tags"]).to eq([])
        expect(response.parsed_body["tracked_tags"]).to eq([])
        expect(response.parsed_body["muted_tags"]).to eq([tag.name])
        expect(response.parsed_body["regular_tags"]).to eq([])
      end.to change { user.tag_users.count }.by(1)

      tag_user = user.tag_users.last

      expect(tag_user.notification_level).to eq(NotificationLevels.all[:muted])
    end
  end
end
