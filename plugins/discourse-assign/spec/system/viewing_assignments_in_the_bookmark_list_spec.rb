# frozen_string_literal: true

RSpec.describe "Assign | Viewing assignments in the bookmark list" do
  fab!(:admin)
  fab!(:assignee) { Fabricate(:user, username: "assigneduser") }

  let(:bookmarks_page) { PageObjects::Pages::UserActivityBookmarks.new }
  let(:bookmark_list) { bookmarks_page.bookmark_list }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = Group::AUTO_GROUPS[:staff].to_s
    sign_in(admin)
  end

  it "shows users only current assignment badges" do
    active_topic = Fabricate(:read_topic, current_user: admin, title: "Topic still assigned")
    Fabricate(:bookmark, user: admin, bookmarkable: active_topic)
    Fabricate(:topic_assignment, topic: active_topic, assigned_to: assignee)

    inactive_topic = Fabricate(:read_topic, current_user: admin, title: "Topic no longer assigned")
    Fabricate(:bookmark, user: admin, bookmarkable: inactive_topic)
    Fabricate(:topic_assignment, topic: inactive_topic, assigned_to: assignee, active: false)

    bookmarks_page.visit(admin)

    expect(bookmark_list).to have_assignee(active_topic, assignee)
    expect(bookmark_list).to have_no_assignment(inactive_topic)
  end
end
