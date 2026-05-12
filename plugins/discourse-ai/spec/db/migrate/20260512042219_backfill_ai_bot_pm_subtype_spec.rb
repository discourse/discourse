# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20260512042219_backfill_ai_bot_pm_subtype",
        )

RSpec.describe BackfillAiBotPmSubtype do
  fab!(:user)
  fab!(:bot_user, :user)

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  def fabricate_pm(subtype: nil, marked: false)
    topic = Fabricate(:private_message_topic, user: user, recipient: bot_user, subtype: subtype)
    if marked
      topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
      topic.save_custom_fields
    end
    topic
  end

  it "backfills custom-field marked PMs to the AI bot subtype" do
    marked_pm = fabricate_pm(marked: true)
    blank_marked_pm = fabricate_pm(subtype: "", marked: true)
    unmarked_pm = fabricate_pm
    public_topic = Fabricate(:topic)
    public_topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    public_topic.save_custom_fields

    described_class.new.up

    expect(marked_pm.reload.subtype).to eq(DiscourseAi::AiBot::TOPIC_AI_BOT_PM_SUBTYPE)
    expect(blank_marked_pm.reload.subtype).to eq(DiscourseAi::AiBot::TOPIC_AI_BOT_PM_SUBTYPE)
    expect(unmarked_pm.reload.subtype).to be_nil
    expect(public_topic.reload.subtype).to be_nil
  end
end
