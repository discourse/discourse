# frozen_string_literal: true

RSpec.describe "Use member checklist" do
  fab!(:user)
  let(:checklist) { PageObjects::Pages::LovelaceMemberChecklist.new }

  before do
    enable_current_plugin
    sign_in(user)
  end

  it "lets members resume, minimize, complete, undo and dismiss their checklist" do
    checklist.open
    expect(checklist).to have_progress("0 of 3 complete")
    expect(checklist).to have_profile_link
    expect(checklist).to be_above_welcome_banner
    checklist.toggle("Complete your profile")
    expect(checklist).to have_progress("1 of 3 complete")
    page.refresh
    expect(checklist).to have_completed_item("Complete your profile")
    checklist.minimize
    expect(checklist).to have_minimized_checklist
    page.refresh
    expect(checklist).to have_minimized_checklist
    checklist.expand
    checklist.toggle("Add a profile picture")
    expect(checklist).to have_progress("2 of 3 complete")
    checklist.toggle("Read community guidelines")
    expect(checklist).to have_progress("3 of 3 complete")
    expect(checklist).to have_celebration
    expect(checklist).to have_profile_link
    checklist.toggle("Complete your profile")
    expect(checklist).to have_progress("2 of 3 complete")
    checklist.dismiss
    expect(checklist).to have_no_checklist
    page.refresh
    expect(checklist).to have_no_checklist
  end

  it "lets members use compact rows and labelled icon controls on wide and narrow screens" do
    page.current_window.resize_to(1400, 1000)
    checklist.open
    expect(checklist).to have_icon_controls
    expect(checklist).to have_compact_rows(stacked: false)
    checklist.toggle_with_keyboard("Complete your profile")
    expect(checklist).to have_completed_item("Complete your profile")
    expect(checklist).to have_profile_link
    page.current_window.resize_to(390, 844)
    expect(checklist).to have_compact_rows(stacked: true)
    expect(checklist).to have_responsive_layout
    checklist.minimize
    expect(checklist).to have_minimized_checklist
    checklist.expand
    expect(checklist).to have_completed_item("Complete your profile")
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  it "keeps the checklist in the reading area with a short progress bar" do
    sidebar = PageObjects::Components::NavigationMenu::Sidebar.new
    page.current_window.resize_to(1400, 1000)
    checklist.open
    expect(sidebar).to be_visible
    expect(checklist).to be_within_reading_area
    expect(checklist).to have_compact_progress_bar
    sidebar.click_header_toggle
    expect(sidebar).to be_not_visible
    expect(checklist).to be_within_reading_area
    expect(checklist).to have_compact_progress_bar
    sidebar.click_header_toggle
    expect(sidebar).to be_visible
    expect(checklist).to be_within_reading_area
    checklist.minimize
    expect(checklist).to be_within_reading_area
    expect(checklist).to have_compact_progress_bar
    checklist.expand
    page.current_window.resize_to(390, 844)
    expect(checklist).to be_within_reading_area
    expect(checklist).to have_compact_progress_bar
    expect(checklist).to have_responsive_layout
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  it "keeps action link colors consistent with their visited styling through completion changes" do
    guidelines = Fabricate(:post)
    SiteSetting.guidelines_topic_id = guidelines.topic_id
    checklist.open
    expect(checklist).to have_consistent_action_colors
    checklist.follow_guidelines
    expect(page).to have_current_path(guidelines.topic.relative_url)
    checklist.open
    expect(checklist).to have_consistent_action_colors
    checklist.toggle("Read community guidelines")
    expect(checklist).to have_completed_item("Read community guidelines")
    expect(checklist).to have_consistent_action_colors
    page.refresh
    expect(checklist).to have_completed_item("Read community guidelines")
    expect(checklist).to have_consistent_action_colors
    checklist.toggle("Read community guidelines")
    expect(checklist).to have_progress("0 of 3 complete")
    expect(checklist).to have_consistent_action_colors
  end

  it "lets mobile members dismiss an untouched checklist" do
    page.current_window.resize_to(390, 844)
    checklist.open
    expect(checklist).to have_responsive_layout
    checklist.dismiss
    expect(checklist).to have_no_checklist
    page.refresh
    expect(checklist).to have_no_checklist
  ensure
    page.current_window.resize_to(1400, 1000)
  end
end
