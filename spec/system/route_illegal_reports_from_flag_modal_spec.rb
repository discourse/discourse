# frozen_string_literal: true
RSpec.describe "Route illegal reports from the flag modal" do
  fab!(:admin)
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:classification) { PageObjects::Components::DsaClassification.new }

  it "offers ordinary flags and links to the configured illegal reporting form" do
    sign_in(admin)
    settings_page.visit("illegal_content_reporting_url")
    reporting_url = URI.join(page.current_url, "/guidelines").to_s
    settings_page.fill_setting("illegal_content_reporting_url", reporting_url)
    settings_page.save_setting("illegal_content_reporting_url")

    sign_in(member)
    topic_page.visit_topic(post.topic)
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :flag)

    expect(flag_modal).to be_open
    expect(classification).to have_no_illegal_flag
    expect(classification).to have_illegal_reporting_link(reporting_url)
    flag_modal.choose_type(:inappropriate)

    reporting_window = window_opened_by { classification.open_illegal_reporting_form }
    within_window(reporting_window) { expect(page).to have_current_path("/guidelines") }
    reporting_window.close
    expect(flag_modal).to be_open

    sign_in(admin)
    page.visit("/review")
    expect(PageObjects::Pages::Review.new).to have_reviewable_items(count: 0)
  end
end
