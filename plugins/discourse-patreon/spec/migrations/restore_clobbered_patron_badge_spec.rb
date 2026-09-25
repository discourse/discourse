# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-patreon/db/migrate/20260925151913_restore_clobbered_patron_badge.rb",
        )

RSpec.describe RestoreClobberedPatronBadge do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  # The shape the badge is left in once another plugin has seeded over its name.
  def clobbered_badge
    Fabricate(
      :badge,
      name: "Patron",
      query: "SELECT user_id, current_timestamp granted_at FROM voice_sessions GROUP BY user_id",
      system: true,
      auto_revoke: false,
      badge_type_id: BadgeType::Bronze,
      description: "Wording the site chose",
      enabled: false,
    )
  end

  it "puts the badge definition back when the patrons group is still there" do
    Fabricate(:group, name: "patrons")
    badge = clobbered_badge

    described_class.new.up
    badge.reload

    expect(badge.query).to include("group_users")
    expect(badge.system).to eq(false)
    expect(badge.auto_revoke).to eq(true)
    expect(badge.badge_type_id).to eq(BadgeType::Gold)
  end

  it "keeps the wording and the enabled state the site chose" do
    Fabricate(:group, name: "patrons")
    badge = clobbered_badge

    described_class.new.up
    badge.reload

    expect(badge.description).to eq("Wording the site chose")
    expect(badge.enabled).to eq(false)
  end

  it "leaves the badge alone on a site that never had the patrons group" do
    badge = clobbered_badge

    described_class.new.up

    expect(badge.reload.query).to include("voice_sessions")
  end
end
