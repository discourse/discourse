# frozen_string_literal: true

require Rails.root.join(
          "plugins/live/db/migrate/20260925151909_rename_voice_patron_badge.rb"
        )

RSpec.describe RenameVoicePatronBadge do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    SeedFu.seed(Rails.root.join("plugins/live/db/fixtures"))
    Live::BadgeGranterHooks.disable_all!
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  # Puts the database back into the state the old fixture left it in.
  def restore_old_badge_name
    DB.exec("UPDATE badges SET name = 'Patron' WHERE name = 'Frequenter'")
  end

  it "renames the live badge in place so the fixture reseeds it without a duplicate" do
    restore_old_badge_name
    badge_id = Badge.find_by(name: "Patron").id

    described_class.new.up
    SeedFu.seed(Rails.root.join("plugins/live/db/fixtures"))

    expect(Badge.find_by(name: "Patron")).to be_nil
    expect(Badge.find_by(name: "Frequenter").id).to eq(badge_id)
  end

  it "hands a badge the site already owned back instead of renaming it" do
    restore_old_badge_name
    DB.exec(
      "UPDATE badges SET created_at = NOW() - INTERVAL '1 year', system = true WHERE name = 'Patron'"
    )

    described_class.new.up

    expect(Badge.find_by(name: "Frequenter")).to be_nil
    expect(Badge.find_by(name: "Patron").system).to eq(false)
  end

  it "hands a Patreon badge back even when its grouping makes it look newest" do
    restore_old_badge_name
    Fabricate(:group, name: "patrons")
    grouping = BadgeGrouping.create!(name: "Supporters", position: 20)
    Fabricate(
      :badge,
      name: "Old Supporter",
      badge_grouping_id: grouping.id
    ).update_columns(created_at: 2.years.ago)
    patron = Badge.find_by(name: "Patron")
    patron.update_columns(
      badge_grouping_id: grouping.id,
      created_at: 1.year.ago,
      system: true
    )

    described_class.new.up

    expect(patron.reload.name).to eq("Patron")
    expect(patron.system).to eq(false)
    expect(Badge.find_by(name: "Frequenter")).to be_nil
  end

  it "ignores a Patron badge that live never seeded over" do
    badge = Fabricate(:badge, name: "Patron", query: "SELECT 1", system: false)

    described_class.new.up

    expect(badge.reload.name).to eq("Patron")
    expect(Badge.where(name: "Frequenter").count).to eq(1)
  end
end
