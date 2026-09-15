# frozen_string_literal: true

require_relative "../../db/post_migrate/20260915134446_restore_voice_badge_preferences"

RSpec.describe RestoreVoiceBadgePreferences do
  it "restores bulk-disabled badges while preserving the latest recorded individual choices" do
    admin = Fabricate(:admin)
    automatic_badge = Badge.find_by!(name: "Mic Check")
    disabled_badge = Badge.find_by!(name: "Host")
    reenabled_badge = Badge.find_by!(name: "Night Owl")
    unrelated_badge =
      Fabricate(:badge, enabled: false, badge_grouping_id: automatic_badge.badge_grouping_id)
    award = Fabricate(:user_badge, badge: automatic_badge)
    logger = StaffActionLogger.new(admin)

    [disabled_badge, reenabled_badge].each do |badge|
      badge.update!(enabled: false)
      logger.log_badge_change(badge)
    end
    reenabled_badge.update!(enabled: true)
    logger.log_badge_change(reenabled_badge)
    disabled_badge.update!(description: "A later edit without changing the preference")
    logger.log_badge_change(disabled_badge)

    Badge.where(plugin_name: Voice::PLUGIN_NAME).update_all(enabled: false)
    Badge.where(id: [automatic_badge.id, disabled_badge.id]).update_all(plugin_name: nil)
    SiteSetting.create!(
      name: "voice_badges_enabled",
      value: "f",
      data_type: SiteSettings::TypeSupervisor.types[:bool],
    )

    described_class.new.migrate(:up)

    expect(automatic_badge.reload.enabled).to eq(true)
    expect(reenabled_badge.reload.enabled).to eq(true)
    expect(disabled_badge.reload.enabled).to eq(false)
    expect(unrelated_badge.reload.enabled).to eq(false)
    expect(award.reload.badge_id).to eq(automatic_badge.id)
    expect(SiteSetting.find_by!(name: "voice_badges_enabled").value).to eq("f")
  end

  it "preserves disabled preferences when the old master switch was not off" do
    badge = Badge.find_by!(name: "Mic Check")
    badge.update!(enabled: false)

    described_class.new.migrate(:up)

    expect(badge.reload.enabled).to eq(false)
  end
end
