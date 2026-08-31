# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Voice mesh privacy warning" do
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }

  before do
    user.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(user)
    install_voice_fake_media
  end

  def click_join
    click_button(I18n.t("js.voice.room.join"))
  end

  it "gates a mesh join behind the warning" do
    visit("/voice/r/#{room.slug}")

    click_join
    expect(page).to have_css(".voice-mesh-privacy-warning-modal")
    click_button(I18n.t("js.voice.mesh_privacy_warning.cancel"))
    expect(page).to have_no_css(".voice-mesh-privacy-warning-modal")
    expect(page).to have_no_css(".voice-room-page__leave")

    click_join
    click_button(I18n.t("js.voice.mesh_privacy_warning.join"))
    expect(page).to have_css(".voice-room-page__leave")
  end

  it "doesn't warn again on a device that opted out" do
    visit("/voice/r/#{room.slug}")

    click_join
    find(".voice-mesh-privacy-warning-modal__dont-show-again input").click
    click_button(I18n.t("js.voice.mesh_privacy_warning.join"))
    expect(page).to have_css(".voice-room-page__leave")
    click_button(I18n.t("js.voice.room.leave"))

    click_join
    expect(page).to have_css(".voice-room-page__leave")
    expect(page).to have_no_css(".voice-mesh-privacy-warning-modal")
  end

  it "doesn't warn when disabled site-wide" do
    SiteSetting.voice_mesh_privacy_warning_enabled = false

    visit("/voice/r/#{room.slug}")

    click_join
    expect(page).to have_css(".voice-room-page__leave")
    expect(page).to have_no_css(".voice-mesh-privacy-warning-modal")
  end
end
