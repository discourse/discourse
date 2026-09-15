# frozen_string_literal: true

require_relative "../../db/migrate/20260915122211_rename_voice_patron_badge"

RSpec.describe RenameVoicePatronBadge do
  it "renames before pre-deployment seeding without changing the ID, preferences, or awards" do
    badge = Badge.find_by!(name: "Voice Patron")
    badge.update!(name: "Patron", enabled: false, plugin_name: nil)
    award = Fabricate(:user_badge, badge: badge)

    migration =
      ActiveRecord::MigrationContext
        .new(Rails.root.join("plugins/voice/db/migrate"))
        .migrations
        .find { |candidate| candidate.name == described_class.name }
    migration&.migrate(:up)
    SeedFu.seed(Rails.root.join("plugins/voice/db/fixtures"))

    expect(Badge.find_by!(name: "Voice Patron")).to eq(badge)
    expect(badge.reload).to have_attributes(name: "Voice Patron", enabled: false)
    expect(award.reload.badge_id).to eq(badge.id)
  end

  it "leaves a Patreon badge unchanged" do
    badge = Fabricate(:badge, name: "Patron", query: "SELECT user_id FROM group_users")

    described_class.new.migrate(:up)

    expect(badge.reload.name).to eq("Patron")
  end
end
