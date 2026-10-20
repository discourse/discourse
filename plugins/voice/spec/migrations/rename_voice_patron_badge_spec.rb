# frozen_string_literal: true

require Rails.root.join("plugins/voice/db/migrate/20260925151909_rename_voice_patron_badge.rb")

RSpec.describe RenameVoicePatronBadge do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))
    Voice::BadgeGranterHooks.disable_all!
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  # Puts the database back into the state the old fixture left it in.
  def restore_old_badge_name
    DB.exec("UPDATE badges SET name = 'Patron' WHERE name = 'Frequenter'")
  end

  it "renames the voice badge in place so the fixture reseeds it without a duplicate" do
    restore_old_badge_name
    badge_id = Badge.find_by(name: "Patron").id

    described_class.new.up
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))

    expect(Badge.find_by(name: "Patron")).to be_nil
    expect(Badge.find_by(name: "Frequenter").id).to eq(badge_id)
  end

  it "hands a badge the site already owned back instead of renaming it" do
    restore_old_badge_name
    DB.exec(
      "UPDATE badges SET created_at = NOW() - INTERVAL '1 year', system = true WHERE name = 'Patron'",
    )

    described_class.new.up

    expect(Badge.find_by(name: "Frequenter")).to be_nil
    expect(Badge.find_by(name: "Patron").system).to eq(false)
  end

  it "ignores a Patron badge that voice never seeded over" do
    badge = Fabricate(:badge, name: "Patron", query: "SELECT 1", system: false)

    described_class.new.up

    expect(badge.reload.name).to eq("Patron")
    expect(Badge.where(name: "Frequenter").count).to eq(1)
  end
end
