# frozen_string_literal: true

describe "Admin House Ad", type: :system do
  fab!(:admin)

  let(:house_ads_page) { PageObjects::Pages::AdminHouseAds.new }
  let(:form) { PageObjects::Components::FormKit.new(".house-ad-form") }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "supports the full house ad lifecycle" do
    house_ads_page.visit_page
    expect(house_ads_page).to have_empty_state

    # Create a new ad
    house_ads_page.click_new_ad
    expect(form.field("visible_to_logged_in_users")).to be_checked
    expect(form.field("visible_to_anons")).to be_checked

    form.field("name").fill_in("My Test Ad")
    form.field("html").fill_in("<h1>hello world</h1>")
    form.field("visible_to_anons").toggle
    form.submit

    expect(toasts).to have_success(I18n.t("js.saved"))
    ad = AdPlugin::HouseAd.last
    expect(ad.name).to eq("My Test Ad")
    expect(ad.visible_to_logged_in_users).to eq(true)
    expect(ad.visible_to_anons).to eq(false)

    # Navigate back to list, verify ad appears
    house_ads_page.click_back
    expect(house_ads_page).to have_ad_listed("My Test Ad")

    # Click into the ad, verify fields populated
    house_ads_page.click_ad("My Test Ad")
    expect(form.field("name")).to have_value("My Test Ad")
    expect(form.field("visible_to_logged_in_users")).to be_checked
    expect(form.field("visible_to_anons")).to be_unchecked

    # Edit and save
    form.field("name").fill_in("Updated Ad")
    form.submit

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(ad.reload.name).to eq("Updated Ad")

    # Navigate back, verify updated name
    house_ads_page.click_back
    expect(house_ads_page).to have_ad_listed("Updated Ad")

    # Navigate back in and delete
    house_ads_page.click_ad("Updated Ad")
    house_ads_page.click_delete

    expect(dialog).to be_open
    dialog.click_yes

    expect(house_ads_page).to have_empty_state
    expect(AdPlugin::HouseAd.exists?(ad.id)).to eq(false)
  end
end
