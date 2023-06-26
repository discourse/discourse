# frozen_string_literal: true

describe "Filtering topics", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:dismiss_new_modal) { PageObjects::Modals::DismissNew.new }
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
  fab!(:topic) { Fabricate(:topic) }

  before { SiteSetting.experimental_new_new_view_groups = group.id }

  it "displays confirmation modal with preselected options" do
    sign_in(user)

    visit("/new")

    expect(topic_list).to have_topic(topic)
    find(".dismiss-read", text: "Dismiss…").click
    expect(dismiss_new_modal).to have_dismiss_topics_checked
    expect(dismiss_new_modal).to have_dismiss_posts_checked
    expect(dismiss_new_modal).to have_untrack_unchecked
  end
end
