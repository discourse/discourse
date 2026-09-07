# frozen_string_literal: true

require Rails.root.join(
          "plugins/voice/db/post_migrate/20260904172314_replace_voice_video_enabled_setting.rb",
        )

RSpec.describe ReplaceVoiceVideoEnabledSetting do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  # The test provider keeps settings in memory; the migration reads the table.
  def insert_old_setting(value)
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('voice_video_enabled', :type, :value, NOW(), NOW())",
      type: SiteSettings::TypeSupervisor.types[:bool],
      value: value,
    )
  end

  def stored(name)
    DB.query_single("SELECT value FROM site_settings WHERE name = :name", name: name)
  end

  it "keeps video off for a site that had disabled it" do
    insert_old_setting("f")

    described_class.new.up

    expect(stored("voice_video_allowed_groups")).to eq([""])
    expect(stored("voice_screen_share_allowed_groups")).to eq([""])
    expect(stored("voice_video_enabled")).to be_empty
  end

  it "leaves the new defaults in place for a site that had video on" do
    insert_old_setting("t")

    described_class.new.up

    expect(stored("voice_video_allowed_groups")).to be_empty
    expect(stored("voice_screen_share_allowed_groups")).to be_empty
    expect(stored("voice_video_enabled")).to be_empty
  end

  it "writes nothing when the old setting was never stored" do
    described_class.new.up

    expect(stored("voice_video_allowed_groups")).to be_empty
  end

  it "does not overwrite a group list an admin already configured" do
    insert_old_setting("f")
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('voice_video_allowed_groups', :type, '13', NOW(), NOW())",
      type: SiteSettings::TypeSupervisor.types[:group_list],
    )

    described_class.new.up

    expect(stored("voice_video_allowed_groups")).to eq(["13"])
  end
end
