# frozen_string_literal: true

describe DiscourseAutomation::Triggers::FLAG_ON_POST_CREATED do
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:second_flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::FLAG_ON_POST_CREATED)
  end

  before { SiteSetting.discourse_automation_enabled = true }

  it "ignores the tags field if tagging is disabled" do
    SiteSetting.tagging_enabled = false

    automation.upsert_field!("tags", "tags", { value: [tag.name] }, target: "trigger")

    expect do
      result = PostActionCreator.spam(flagger, Fabricate(:post, topic: Fabricate(:topic)))
      expect(result.success).to eq(true)
    end.to change { automation.reload.stats.count }.by(1)
  end

  it "only triggers the automation if flagged post is in a topic with the specified tags defined by the tags field" do
    automation.upsert_field!("tags", "tags", { value: [tag.name] }, target: "trigger")

    post_action_id = nil

    triggered_automations =
      capture_contexts do
        expect do
          result = PostActionCreator.spam(flagger, post)
          expect(result.success).to eq(true)
          post_action_id = result.post_action.id

          result = PostActionCreator.spam(flagger, Fabricate(:post, topic: Fabricate(:topic)))
          expect(result.success).to eq(true)
        end.to change { automation.reload.stats.count }.by(1)
      end

    expect(triggered_automations.length).to eq(1)

    triggered_automation = triggered_automations.first

    expect(triggered_automation["kind"]).to eq(DiscourseAutomation::Triggers::FLAG_ON_POST_CREATED)
    expect(triggered_automation["post_action_id"]).to eq(post_action_id)
  end

  it "only triggers the automation if flagged post is in a topic with the specified categories defined by the categories field" do
    automation.upsert_field!(
      "categories",
      "categories",
      { value: [category.id] },
      target: "trigger",
    )

    post_action_id = nil

    triggered_automations =
      capture_contexts do
        expect do
          result = PostActionCreator.spam(flagger, post)
          expect(result.success).to eq(true)
          post_action_id = result.post_action.id

          result = PostActionCreator.spam(flagger, Fabricate(:post, topic: Fabricate(:topic)))
          expect(result.success).to eq(true)
        end.to change { automation.reload.stats.count }.by(1)
      end

    expect(triggered_automations.length).to eq(1)

    triggered_automation = triggered_automations.first

    expect(triggered_automation["kind"]).to eq(DiscourseAutomation::Triggers::FLAG_ON_POST_CREATED)
    expect(triggered_automation["post_action_id"]).to eq(post_action_id)
  end

  it "only triggers the automation if flag is of the specified flag type defined by the flag_type field" do
    automation.upsert_field!(
      "flag_type",
      "choices",
      { value: PostActionType.types[:off_topic] },
      target: "trigger",
    )

    post_action_id = nil

    triggered_automations =
      capture_contexts do
        expect do
          result = PostActionCreator.spam(flagger, post)
          expect(result.success).to eq(true)

          result = PostActionCreator.off_topic(second_flagger, post)
          expect(result.success).to eq(true)
          post_action_id = result.post_action.id
        end.to change { automation.reload.stats.count }.by(1)
      end

    expect(triggered_automations.length).to eq(1)

    triggered_automation = triggered_automations.first

    expect(triggered_automation["post_action_id"]).to eq(post_action_id)
    expect(triggered_automation["kind"]).to eq(DiscourseAutomation::Triggers::FLAG_ON_POST_CREATED)
  end
end
