# frozen_string_literal: true

describe "Change Owner Modal", type: :system do
  fab!(:post) { Fabricate(:post, raw: "This is some post to change owner for") }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:admin)
  let(:user) { post.user }
  let(:topic) { post.topic }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:change_owner_modal) { PageObjects::Modals::ChangeOwner.new }

  before { sign_in(admin) }

  def visit_topic_and_open_change_owner_modal(post)
    topic_page.visit_topic(topic)
    topic_page.expand_post_actions(post)
    topic_page.expand_post_admin_actions(post)
    topic_page.click_post_admin_action_button(post, :change_owner)
  end

  it "changes owner of a post" do
    visit_topic_and_open_change_owner_modal(post)
    change_owner_modal.select_new_owner(other_user)
    change_owner_modal.confirm_new_owner
    expect(page).not_to have_css ".change-ownership-modal"

    displayed_username = topic_page.post_by_number(post).find(".first.username").text
    expect(displayed_username).to eq other_user.username
  end
end
