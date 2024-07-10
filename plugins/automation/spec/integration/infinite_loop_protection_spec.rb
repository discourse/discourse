# frozen_string_literal: true

describe "Infinite loop protection" do
  fab!(:automation_1) do
    Fabricate(:automation, script: "auto_responder", trigger: "post_created_edited", enabled: true)
  end

  fab!(:automation_2) do
    Fabricate(:automation, script: "auto_responder", trigger: "post_created_edited", enabled: true)
  end

  before do
    SiteSetting.discourse_automation_enabled = true

    automation_1.upsert_field!(
      "word_answer_list",
      "key-value",
      { value: [{ key: "", value: "this is the reply" }].to_json },
    )
    automation_2.upsert_field!(
      "word_answer_list",
      "key-value",
      { value: [{ key: "", value: "this is the reply" }].to_json },
    )

    automation_1.upsert_field!(
      "answering_user",
      "user",
      { value: Fabricate(:user).username },
      target: "script",
    )
    automation_2.upsert_field!(
      "answering_user",
      "user",
      { value: Fabricate(:user).username },
      target: "script",
    )
  end

  it "prevents infinite loop of 2 auto_responder automations triggering each other" do
    expect do
      PostCreator.create!(Fabricate(:user), raw: "post", title: "topic", skip_validations: true)
    end.to change { Post.count }.by(3)
  end
end
