# frozen_string_literal: true

describe DiscourseAutomation::Triggers::FLAG_CREATED do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:second_flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggers::FLAG_CREATED) }

  before do
    DiscourseAutomation::Scriptable.add("capture_flag_created") do
      triggerables [DiscourseAutomation::Triggers::FLAG_CREATED]
      script { |context| DiscourseAutomation::CapturedContext.add(context) }
    end

    automation.update!(script: "capture_flag_created")

    SiteSetting.tagging_enabled = true
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]
    automation.upsert_field!(
      "categories",
      "categories",
      { value: [category.id] },
      target: "trigger",
    )
    automation.upsert_field!("tags", "tags", { value: [tag.name] }, target: "trigger")
  end

  after { DiscourseAutomation::Scriptable.remove("capture_flag_created") }

  it "fires and fills placeholders when filters match" do
    list =
      capture_contexts do
        previous = automation.stats.count
        result = PostActionCreator.spam(flagger, post)
        expect(result.success).to eq(true)
        expect(automation.reload.stats.count).to eq(previous + 1)
      end

    expect(list.length).to eq(1)
    placeholders = list[0]["placeholders"]
    expect(placeholders["topic_title"]).to eq(topic.title)
    expect(placeholders["flagger_username"]).to eq(flagger.username)
    expect(placeholders["flagged_username"]).to eq(post.user.username)
    expect(placeholders["flag_type"]).to eq(
      PostActionTypeView.new.names[PostActionType.types[:spam]],
    )
  end

  it "can restrict by flag type" do
    automation.upsert_field!(
      "flag_type",
      "choices",
      { value: PostActionType.types[:off_topic] },
      target: "trigger",
    )

    list =
      capture_contexts do
        previous = automation.stats.count
        result = PostActionCreator.spam(flagger, post)
        expect(result.success).to eq(true)
        expect(automation.reload.stats.count).to eq(previous)
      end
    expect(list).to be_blank

    list =
      capture_contexts do
        previous = automation.reload.stats.count
        result = PostActionCreator.off_topic(second_flagger, post)
        expect(result.success).to eq(true)
        expect(automation.reload.stats.count).to eq(previous + 1)
      end

    expect(list.length).to eq(1)
  end
end
