# frozen_string_literal: true

require Rails.root.join(
          "plugins/voice/db/post_migrate/20260903195501_enable_voice_badges_by_default.rb",
        )

RSpec.describe EnableVoiceBadgesByDefault do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
    Voice::BadgeGranterHooks.disable_all!
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def voice_badges
    Badge.joins(:badge_grouping).where(badge_groupings: { name: "Voice" })
  end

  it "enables the voice badges on sites that never set the setting" do
    described_class.new.up

    expect(voice_badges.where(enabled: false)).to be_empty
  end

  it "leaves the badges alone on sites that explicitly disabled them" do
    # The test provider keeps settings in memory; the migration reads the table.
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('voice_badges_enabled', :type, 'f', NOW(), NOW())",
      type: SiteSettings::TypeSupervisor.types[:bool],
    )

    described_class.new.up

    expect(voice_badges.where(enabled: true)).to be_empty
  end

  it "does not touch badges outside the Voice grouping" do
    Badge.find_by(name: "Editor").update!(enabled: false)

    described_class.new.up

    expect(Badge.find_by(name: "Editor").enabled).to eq(false)
  end
end
