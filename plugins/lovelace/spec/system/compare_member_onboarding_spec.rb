# frozen_string_literal: true

require_relative "page_objects/member_onboarding"

RSpec.describe "Compare member onboarding" do
  fab!(:admin)
  fab!(:user)

  let(:onboarding) { PageObjects::Pages::LovelaceMemberOnboarding.new }
  let(:checklist) { PageObjects::Pages::LovelaceMemberChecklist.new }

  around do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  before { enable_current_plugin }

  it "lets admins and members compare saved edits while keeping their progress separate" do
    sign_in(user)
    checklist.open
    expect(checklist).to have_progress("0 of 3 complete")
    checklist.toggle("Complete your profile")
    expect(checklist).to have_progress("1 of 3 complete")

    using_session(:admin) do
      sign_in(admin)
      onboarding.open
      expect(onboarding).to have_progress("0 of 3 complete")
      onboarding.preview_complete("Add a profile picture")
      expect(onboarding).to have_progress("1 of 3 complete")
      onboarding.edit_item("Complete your profile")
      onboarding.editor.field("title").fill_in("Introduce yourself")
      onboarding.editor.submit
      expect(onboarding).to have_saved_item("Introduce yourself")
      onboarding.add_suggestion("Set up your notifications")
      expect(onboarding).to have_saved_item("Set up your notifications")
      expect(onboarding).to have_progress("1 of 4 complete")
    end

    page.refresh
    expect(checklist).to have_progress("1 of 4 complete")
    expect(checklist).to have_completed_item("Introduce yourself")
    checklist.toggle("Set up your notifications")
    expect(checklist).to have_progress("2 of 4 complete")

    using_session(:admin) do
      expect(onboarding).to have_progress("1 of 4 complete")
      page.refresh
      expect(onboarding).to have_saved_item("Introduce yourself")
      expect(onboarding).to have_saved_item("Set up your notifications")
      expect(onboarding).to have_progress("0 of 4 complete")
      checklist.open
      expect(checklist).to have_progress("0 of 4 complete")
    end

    page.refresh
    expect(checklist).to have_progress("2 of 4 complete")
    expect(checklist).to have_completed_item("Introduce yourself")
    expect(checklist).to have_completed_item("Set up your notifications")
  end

  it "keeps admin saves available after opening a member session" do
    sign_in(admin)
    onboarding.open

    using_session(:member) do
      sign_in(user)
      checklist.open
      expect(checklist).to have_progress("0 of 3 complete")
    end

    onboarding.add_suggestion("Set up your notifications")
    expect(onboarding).to have_saved_item("Set up your notifications")
    onboarding.move_first_down
    expect(onboarding).to have_order(
      [
        "Complete your profile",
        "Add a profile picture",
        "Read community guidelines",
        "Set up your notifications",
      ],
    )
    onboarding.add_item("Explore the community")
    expect(onboarding).to have_saved_item("Explore the community")
    page.refresh
    expect(onboarding).to have_order(
      [
        "Complete your profile",
        "Add a profile picture",
        "Read community guidelines",
        "Set up your notifications",
        "Explore the community",
      ],
    )
    using_session(:member) do
      page.refresh
      expect(checklist).to have_progress("0 of 5 complete")
    end
  end
end
