# frozen_string_literal: true

describe DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:cool_tag) { Fabricate(:tag) }
  fab!(:bad_tag) { Fabricate(:tag) }
  fab!(:another_tag) { Fabricate(:tag) }

  fab!(:category)

  fab!(:user)

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:everyone]
  end

  context "when watching a cool tag" do
    before do
      automation.upsert_field!(
        "watching_tags",
        "tags",
        { value: [cool_tag.name] },
        target: "trigger",
      )
      automation.reload
    end

    it "fills placeholders correctly" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list[0]["placeholders"]).to eq(
        { "topic_title" => topic_0.title, "topic_url" => topic_0.relative_url },
      )
    end

    it "should fire the trigger if the tag is added" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
      expect(list[0]["user"]).to eq(user)
    end

    it "should fire the trigger if the tag is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts { DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), []) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
      expect(list[0]["user"]).to eq(user)
    end

    it "should not fire if the tag is not present" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [bad_tag.name])
        end

      expect(list.length).to eq(0)
    end
  end

  context "when watching a few cool tags" do
    fab!(:cool_tag_2) { Fabricate(:tag) }
    fab!(:cool_tag_3) { Fabricate(:tag) }

    before do
      automation.upsert_field!(
        "watching_tags",
        "tags",
        { value: [cool_tag.name, cool_tag_2.name, cool_tag_3.name] },
        target: "trigger",
      )
      automation.reload
    end

    it "should fire the trigger if any tag is added" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should fire the trigger if any tag is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts { DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), []) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should not fire if the tag is not present" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [bad_tag.name])
        end

      expect(list.length).to eq(0)
    end

    it "should fire the trigger if a tag is add and one is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag_2.name])
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end
  end

  context "when watching a category" do
    before do
      automation.upsert_field!(
        "watching_categories",
        "categories",
        { value: [category.id] },
        target: "trigger",
      )
      automation.reload
    end

    it "should fire the trigger if the tag is added" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)
      topic_1 = Fabricate(:topic, user: user, tags: [], category: Fabricate(:category))

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [bad_tag.name])
          DiscourseTagging.tag_topic_by_names(topic_1, Guardian.new(user), [bad_tag.name])
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should fire the trigger if the tag is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts { DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), []) }
      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should not fire if not the watching category" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: Fabricate(:category))

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list.length).to eq(0)
    end
  end

  context "when watching a few categories" do
    fab!(:category_2) { Fabricate(:category) }
    fab!(:category_3) { Fabricate(:category) }

    before do
      automation.upsert_field!(
        "watching_categories",
        "categories",
        { value: [category.id, category_2.id, category_3.id] },
        target: "trigger",
      )
      automation.reload
    end

    it "should fire the trigger if any tag is added" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)
      topic_1 = Fabricate(:topic, user: user, tags: [], category: category_2)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [bad_tag.name])
          DiscourseTagging.tag_topic_by_names(topic_1, Guardian.new(user), [bad_tag.name])
        end

      expect(list.length).to eq(2)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should fire the trigger if any tag is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts { DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), []) }
      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should not fire if not the watching category" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: Fabricate(:category))

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list.length).to eq(0)
    end
  end

  context "when without any watching tags or categories" do
    it "should fire the trigger if the tag is added" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should fire the trigger if the tag is removed" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts { DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), []) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
    end

    it "should send the correct removed tags in context" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(
            topic_0,
            Guardian.new(user),
            [bad_tag.name, another_tag.name],
          )
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
      expect(list[0]["added_tags"]).to match_array([bad_tag.name, another_tag.name])
      expect(list[0]["removed_tags"]).to eq([cool_tag.name])
    end

    it "should send the correct added tags in context" do
      topic_0 = Fabricate(:topic, user: user, tags: [cool_tag], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(
            topic_0,
            Guardian.new(user),
            [cool_tag.name, another_tag.name],
          )
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
      expect(list[0]["added_tags"]).to eq([another_tag.name])
      expect(list[0]["removed_tags"]).to eq([])
    end

    it "should not fire the trigger on PMs by default" do
      pm = Fabricate(:private_message_topic)
      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(
            pm,
            Guardian.new(user),
            [cool_tag.name, another_tag.name],
          )
        end
      expect(list.length).to eq(0)
    end

    it "should fire the trigger on PMs if trigger_with_pms is set" do
      automation.upsert_field!(
        "trigger_with_pms",
        "boolean",
        { "value" => true },
        target: "trigger",
      )

      pm = Fabricate(:private_message_topic)
      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(
            pm,
            Guardian.new(user),
            [cool_tag.name, another_tag.name],
          )
        end
      expect(list.length).to eq(1)
    end
  end
end
