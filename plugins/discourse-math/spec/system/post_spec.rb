# frozen_string_literal: true

RSpec.describe "Discourse Math - post", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  before do
    SiteSetting.discourse_math_enabled = true
    sign_in(current_user)
  end

  it "works with details" do
    post =
      create_post(
        user: current_user,
        raw: "This is maths:\n\n[details='math']\n$E=mc^2$\n[/details]",
      )
    visit(post.topic.url)

    find("#post_1 details").click

    expect(page).to have_selector("#MJXc-Node-6", text: "2")
  end
end
