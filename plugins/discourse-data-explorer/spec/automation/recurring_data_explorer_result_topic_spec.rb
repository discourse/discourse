# frozen_string_literal: true

require "rails_helper"

describe "RecurringDataExplorerResultTopic" do
  fab!(:admin)

  fab!(:user)
  fab!(:another_user) { Fabricate(:user) }
  fab!(:group_user) { Fabricate(:user) }
  fab!(:not_allowed_user) { Fabricate(:user) }
  fab!(:topic)

  fab!(:group) { Fabricate(:group, users: [user, another_user]) }

  fab!(:automation) do
    Fabricate(:automation, script: "recurring_data_explorer_result_topic", trigger: "recurring")
  end
  fab!(:query) { Fabricate(:query, sql: "SELECT 'testabcd' AS data") }
  fab!(:query_group) { Fabricate(:query_group, query: query, group: group) }

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.discourse_automation_enabled = true

    automation.upsert_field!("query_id", "choices", { value: query.id })
    automation.upsert_field!("topic_id", "text", { value: topic.id })
    automation.upsert_field!(
      "query_params",
      "key-value",
      { value: [%w[from_days_ago 0], %w[duration_days 15]] },
    )
    automation.upsert_field!(
      "recurrence",
      "period",
      { value: { interval: 1, frequency: "day" } },
      target: "trigger",
    )
    automation.upsert_field!("start_date", "date_time", { value: 2.minutes.ago }, target: "trigger")
  end

  context "when using recurring trigger" do
    it "sends the post at recurring date_date" do
      freeze_time 1.day.from_now do
        expect { Jobs::DiscourseAutomation::Tracker.new.execute }.to change {
          topic.reload.posts.count
        }.by(1)

        expect(topic.posts.last.raw).to eq(
          I18n.t(
            "data_explorer.report_generator.post.body",
            query_name: query.name,
            table: "| data |\n| :----- |\n| testabcd |\n",
            base_url: Discourse.base_url,
            query_id: query.id,
            created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
            timezone: Time.zone.name,
          ).chomp,
        )
      end
    end

    it "has appropriate content from the report generator" do
      freeze_time
      automation.update(last_updated_by_id: admin.id)
      automation.trigger!

      expect(topic.posts.last.raw).to eq(
        I18n.t(
          "data_explorer.report_generator.post.body",
          query_name: query.name,
          table: "| data |\n| :----- |\n| testabcd |\n",
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        ).chomp,
      )
    end

    it "does not create the post if skip_empty" do
      query.update!(sql: "SELECT NULL LIMIT 0")
      automation.upsert_field!("skip_empty", "boolean", { value: true })

      automation.update(last_updated_by_id: admin.id)

      expect { automation.trigger! }.to_not change { Post.count }
    end

    it "works with a query that returns URLs in a number,url format" do
      freeze_time
      query.update!(sql: "SELECT 3 || ',https://test.com' AS some_url")
      automation.update(last_updated_by_id: admin.id)
      automation.trigger!

      expect(topic.posts.last.raw).to eq(
        I18n.t(
          "data_explorer.report_generator.post.body",
          query_name: query.name,
          table: "| some_url |\n| :----- |\n| [3](https://test.com) |\n",
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        ).chomp,
      )
    end
  end
end
