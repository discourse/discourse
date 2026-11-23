# frozen_string_literal: true

describe "Number user field" do
  fab!(:current_user, :trust_level_2)
  fab!(:user, :trust_level_2)
  fab!(:post) { Fabricate(:post, user:) }
  fab!(:number_field) do
    Fabricate(
      :user_field,
      name: "Score",
      field_type: "number",
      show_on_profile: true,
      show_on_user_card: true,
    )
  end

  let(:user_page) { PageObjects::Pages::User.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:user_card) { PageObjects::Components::UserCard.new }

  before do
    user.set_user_field(number_field.id, "0")
    user.save_custom_fields
    sign_in(current_user)
  end

  it "shows a value of 0 on the profile and the user card" do
    user_page.visit(user)

    expect(user_page).to have_public_user_field("Score", value: "0")

    topic_page.visit_topic(post.topic)
    topic_page.click_post_author_avatar(post)

    expect(user_card).to have_public_user_field("Score", value: "0")
  end
end
