# frozen_string_literal: true

RSpec.describe "Managing multiple topic assignments" do
  fab!(:admin)
  fab!(:martin) { Fabricate(:moderator, username: "martin") }
  fab!(:sam) { Fabricate(:moderator, username: "sam") }
  fab!(:topic) do
    Fabricate(
      :topic_with_op,
      title: "The Maltese Falcon — Dashiell Hammett's Sam Spade",
      raw:
        "Please review the character references, publication details, and sources for the reading guide.",
    )
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }
  let(:assignment_menu) do
    PageObjects::Components::SelectKit.new("#topic-footer-dropdown-reassign")
  end

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allow_multiple_topic_assignees = true
    SiteSetting.prioritize_full_name_in_ux = false
    Fabricate(
      :topic_assignment,
      topic: topic,
      assigned_to: martin,
      assigned_by_user: admin,
      note: "Review the Sam Spade references.",
    )
    Fabricate(
      :topic_assignment,
      topic: topic,
      assigned_to: sam,
      assigned_by_user: admin,
      note: "Check the publication details.",
    )
    sign_in(admin)
  end

  it "lets the user edit one assignee's note and remove another from the footer" do
    visit "/t/#{topic.id}"

    expect(topic_page).to have_topic_assignee(martin, note: "Review the Sam Spade references.")
    expect(topic_page).to have_topic_assignee(sam, note: "Check the publication details.")

    assignment_menu.expand
    [martin, sam].each do |user|
      expect(assignment_menu).to have_option_name(
        I18n.t("js.discourse_assign.topic_level_menu.unassign_from_topic", username: user.username),
      )
    end
    assignment_menu.select_row_by_value("reassign")

    expect(assign_modal).to have_topic_assignees(martin, sam)
    assign_modal.edit_topic_note(
      martin,
      "Character references reviewed; check the final citations.",
    )
    assign_modal.confirm
    expect(assign_modal).to be_closed

    page.refresh
    expect(topic_page).to have_topic_assignee(
      martin,
      note: "Character references reviewed; check the final citations.",
    )
    expect(topic_page).to have_topic_assignee(sam, note: "Check the publication details.")

    assignment_menu.select_row_by_name(
      I18n.t("js.discourse_assign.topic_level_menu.unassign_from_topic", username: sam.username),
    )
    expect(topic_page).to have_no_topic_assignee(sam)
    expect(topic_page).to have_topic_assignee(martin)

    page.refresh
    expect(topic_page).to have_no_topic_assignee(sam)
    expect(topic_page).to have_topic_assignee(
      martin,
      note: "Character references reviewed; check the final citations.",
    )
  end
end
