# frozen_string_literal: true

describe DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:cool_tag) { Fabricate(:tag) }
  fab!(:bad_tag) { Fabricate(:tag) }
  fab!(:category)

  fab!(:user)

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED)
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]
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

    it "fires the trigger" do
      topic_0 = Fabricate(:topic, user: user, tags: [], category: category)

      list =
        capture_contexts do
          DiscourseTagging.tag_topic_by_names(topic_0, Guardian.new(user), [cool_tag.name])
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

    it "fires the trigger" do
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
  end
end
