# frozen_string_literal: true

require Rails.root.join("db/migrate/20250902072941_sync_timerable_id_topic_id.rb")

RSpec.describe SyncTimerableIdTopicId do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "works" do
    DB.exec("DROP TRIGGER IF EXISTS topic_timers_topic_id_trigger ON topic_timers")
    Migration::ColumnDropper.drop_readonly(:topic_timers, :topic_id)
    DB.exec("ALTER TABLE topic_timers ALTER COLUMN timerable_id DROP NOT NULL")

    DB.exec(
      "INSERT INTO topic_timers (execute_at, status_type, type, created_at, updated_at, user_id, topic_id)
      VALUES (NOW() + INTERVAL '60 minutes', 0, 'TopicTimer', NOW(), NOW(), 1, 12345)",
    )

    # Insert with id `20000` to ensure batching works as expected.
    DB.exec(
      "INSERT INTO topic_timers (id, execute_at, status_type, type, created_at, updated_at, user_id, topic_id)
      VALUES (20000, NOW() + INTERVAL '60 minutes', 0, 'TopicTimer', NOW(), NOW(), 1, 67890)",
    )

    SyncTimerableIdTopicId.new.up

    row = DB.query("SELECT * FROM topic_timers WHERE topic_id = 12345")[0]

    expect(row.timerable_id).to eq(12_345)

    row = DB.query("SELECT * FROM topic_timers WHERE topic_id = 67890")[0]

    expect(row.timerable_id).to eq(67_890)
  end
end
