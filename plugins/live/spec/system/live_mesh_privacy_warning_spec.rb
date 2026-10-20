# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Live mesh privacy warning" do
  fab!(:user)
  fab!(:room) { Fabricate(:live_room, public: true) }

  before do
    user.activate
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    sign_in(user)
    install_live_fake_media
  end

  def click_join
    click_button(I18n.t("js.live.room.join"))
  end

  it "gates a mesh join behind the warning" do
    visit("/live/r/#{room.slug}")

    click_join
    expect(page).to have_css(".live-mesh-privacy-warning-modal")
    click_button(I18n.t("js.live.mesh_privacy_warning.cancel"))
    expect(page).to have_no_css(".live-mesh-privacy-warning-modal")
    expect(page).to have_no_css(".live-room-page__leave")

    click_join
    click_button(I18n.t("js.live.mesh_privacy_warning.join"))
    expect(page).to have_css(".live-room-page__leave")
  end

  it "doesn't warn again on a device that opted out" do
    visit("/live/r/#{room.slug}")

    click_join
    find(".live-mesh-privacy-warning-modal__dont-show-again input").click
    click_button(I18n.t("js.live.mesh_privacy_warning.join"))
    expect(page).to have_css(".live-room-page__leave")
    click_button(I18n.t("js.live.room.leave"))

    click_join
    expect(page).to have_css(".live-room-page__leave")
    expect(page).to have_no_css(".live-mesh-privacy-warning-modal")
  end

  it "doesn't warn when disabled site-wide" do
    SiteSetting.live_mesh_privacy_warning_enabled = false

    visit("/live/r/#{room.slug}")

    click_join
    expect(page).to have_css(".live-room-page__leave")
    expect(page).to have_no_css(".live-mesh-privacy-warning-modal")
  end
end
