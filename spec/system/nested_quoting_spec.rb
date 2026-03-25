# frozen_string_literal: true

RSpec.describe "Nested view quoting" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) do
    Fabricate(:post, topic: topic, user: user, post_number: 1, raw: "Original post content here")
  end
  fab!(:root_reply) do
    Fabricate(
      :post,
      topic: topic,
      user: Fabricate(:user),
      raw: "This is a root reply to quote from",
    )
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  def nested_post_cooked_selector(post)
    "[data-post-number='#{post.post_number}'] .cooked p"
  end

  it "shows the quote button when selecting text in a nested post" do
    nested_view.visit_nested(topic)
    expect(nested_view).to have_post(root_reply)

    select_text_range(nested_post_cooked_selector(root_reply), 0, 5)
    expect(page).to have_css(".quote-button")
  end

  it "inserts a quote into the composer when clicking the quote button" do
    nested_view.visit_nested(topic)
    expect(nested_view).to have_post(root_reply)

    select_text_range(nested_post_cooked_selector(root_reply), 0, 7)
    expect(page).to have_css(".quote-button")
    find(".quote-button .insert-quote").click

    expect(composer).to be_opened
    expect(composer.composer_input.value).to include(
      "[quote=\"#{root_reply.user.username}, post:#{root_reply.post_number}, topic:#{topic.id}",
    )
  end

  it "shows the quote button when selecting text in the OP" do
    nested_view.visit_nested(topic)
    expect(nested_view).to have_op_post

    select_text_range(".nested-view__op .cooked p", 0, 8)
    expect(page).to have_css(".quote-button")
  end
end
