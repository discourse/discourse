# frozen_string_literal: true

require Rails.root.join("plugins/live/db/post_migrate/20261013160643_rename_voice_to_live.rb")

RSpec.describe RenameVoiceToLive do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    described_class::RENAMED_TABLES.each do |old_name, new_name|
      DB.exec("ALTER TABLE #{new_name} RENAME TO #{old_name}")
      DB.exec("ALTER INDEX #{new_name}_pkey RENAME TO #{old_name}_pkey")
      DB.exec("ALTER SEQUENCE #{new_name}_id_seq RENAME TO #{old_name}_id_seq")
    end
    DB.exec("ALTER INDEX idx_live_sessions_orphaned RENAME TO idx_voice_sessions_orphaned")
    DB.exec(<<~SQL)
      ALTER TABLE voice_co_presences
      RENAME CONSTRAINT chk_live_co_presences_user_order TO chk_voice_co_presences_user_order
    SQL
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def relation_names(pattern)
    DB.query_single("SELECT relname FROM pg_class WHERE relname ~ ?", pattern)
  end

  it "renames the tables and their custom-named indexes and constraints" do
    described_class.new.up

    expect(relation_names("^voice_")).to be_empty
    expect(relation_names("^live_")).to include(*described_class::RENAMED_TABLES.values.map(&:to_s))
    expect(relation_names("^idx_live_sessions_orphaned$")).to be_present
    expect(
      DB.query_single(
        "SELECT conname FROM pg_constraint WHERE conname = 'chk_live_co_presences_user_order'",
      ),
    ).to be_present
  end

  it "renames site settings without clobbering ones already using the new name" do
    insert_setting = ->(name, value) do
      DB.exec(
        "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES (:name, :type, :value, NOW(), NOW())",
        name:,
        value:,
        type: SiteSettings::TypeSupervisor.types[:bool],
      )
    end
    insert_setting.call("voice_verbose_logging", "t")
    insert_setting.call("voice_chat_enabled", "f")
    insert_setting.call("live_chat_enabled", "t")

    described_class.new.up

    settings = DB.query("SELECT name, value FROM site_settings WHERE name ~ '^(voice|live)_'")
    expect(settings.map { |s| [s.name, s.value] }).to contain_exactly(
      %w[live_verbose_logging t],
      %w[voice_chat_enabled f],
      %w[live_chat_enabled t],
    )
  end

  it "preserves voice in the rest of a setting name" do
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())",
      "voice_max_voice_quality",
      SiteSettings::TypeSupervisor.types[:enum],
      "standard",
    )

    described_class.new.up

    expect(
      DB.query_single("SELECT name, value FROM site_settings WHERE name LIKE '%max%quality'"),
    ).to eq(%w[live_max_voice_quality standard])
  end

  it "moves upcoming change history to the new setting name" do
    UpcomingChangeEvent.where(upcoming_change_name: %w[voice_enabled live_enabled]).delete_all
    UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: "voice_enabled")

    described_class.new.up

    expect(
      UpcomingChangeEvent.where(upcoming_change_name: "live_enabled").pluck(:event_type),
    ).to eq(["added"])
    expect(UpcomingChangeEvent.where(upcoming_change_name: "voice_enabled")).to be_empty
  end

  it "drops once-off upcoming change events the new name already has" do
    UpcomingChangeEvent.where(upcoming_change_name: %w[voice_enabled live_enabled]).delete_all
    UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: "voice_enabled")
    UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: "live_enabled")

    described_class.new.up

    expect(UpcomingChangeEvent.where(upcoming_change_name: "live_enabled").count).to eq(1)
    expect(UpcomingChangeEvent.where(upcoming_change_name: "voice_enabled")).to be_empty
  end

  it "renames reviewables, plugin store rows, badge groupings and chat thread markers" do
    reviewable = Fabricate(:reviewable)
    DB.exec(
      "UPDATE reviewables SET type = 'ReviewableVoiceUser', type_source = 'voice' WHERE id = ?",
      reviewable.id,
    )
    PluginStore.set("voice", "livekit_agent_bot_id", 42)
    BadgeGrouping.where(name: "Live").delete_all
    grouping = BadgeGrouping.create!(name: "Voice", position: 99)
    thread = Fabricate(:chat_thread)
    thread.upsert_custom_fields("voice_room_id" => 7)

    described_class.new.up

    expect(
      DB.query_single("SELECT type, type_source FROM reviewables WHERE id = ?", reviewable.id),
    ).to eq(%w[ReviewableLiveUser live])
    expect(PluginStore.get("live", "livekit_agent_bot_id")).to eq(42)
    expect(grouping.reload.name).to eq("Live")
    expect(thread.reload.custom_fields).to eq("live_room_id" => "7")
  end
end
