# frozen_string_literal: true

describe "User Card", type: :system do
  fab!(:current_user, :admin)
  fab!(:topic) { Fabricate(:post).topic }
  fab!(:user)
  let(:mention) { "@#{user.username}" }
  let!(:post_with_mention) do
    PostCreator.create!(current_user, topic_id: topic.id, raw: "Hello #{mention}")
  end
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:user_card) { PageObjects::Components::UserCard.new }
  let(:mention_post) { PageObjects::Components::Post.new(post_with_mention.post_number) }

  before { sign_in(current_user) }

  context "when the mentioned user has set a status" do
    fab!(:user_status) { Fabricate(:user_status, user: user) }

    before { SiteSetting.enable_user_status = true }

    it "is still possible to view the user card via a mention even there's a status next to the mention" do
      topic_page.visit_topic(topic)

      mention_anchors = mention_post.mentions_of(user)
      expect(mention_anchors.size).to eq(1)

      mention_anchors.first.click

      expect(user_card).to be_visible
      expect(user_card).to be_showing_user(user.username)
    end
  end

  context "when filtering posts by user" do
    fab!(:another_user, :user)
    let!(:first_post_by_another_user) do
      PostCreator.create!(another_user, topic_id: topic.id, raw: "First post by another user")
    end
    let!(:second_post_by_another_user) do
      PostCreator.create!(another_user, topic_id: topic.id, raw: "Second post by another user")
    end

    it "shows filter button when user has 2+ posts in the topic" do
      topic_page.visit_topic(topic)
      topic_page.click_post_author_avatar(first_post_by_another_user)

      expect(user_card).to be_visible
      expect(user_card).to have_filter_button
      expect(user_card.filter_button_text).to match(I18n.t("js.topic.filter_to", count: 2))
    end

    it "does not show filter button when user has less than 2 posts" do
      topic_page.visit_topic(topic)
      topic_page.click_post_author_avatar(topic.posts.first)

      expect(user_card).to be_visible
      expect(user_card).to have_no_filter_button
    end

    context "when user has hidden profile" do
      before do
        SiteSetting.allow_users_to_hide_profile = true
        another_user.user_option.update!(hide_profile: true)
        # Sign in as regular user (not admin) to see hidden profile behavior
        sign_in(user)
      end

      it "shows filter button with post count for hidden profile" do
        topic_page.visit_topic(topic)
        topic_page.click_post_author_avatar(first_post_by_another_user)

        expect(user_card).to be_showing_user(another_user.username)
        expect(user_card).to have_profile_hidden
        expect(user_card).to have_filter_button
        expect(user_card.filter_button_text).to match(I18n.t("js.topic.filter_to", count: 2))
      end
    end

    context "when user is deactivated" do
      before do
        another_user.update!(active: false)
        # Sign in as regular user (not admin) to see deactivated user behavior
        sign_in(user)
      end

      it "shows filter button with post count for deactivated user" do
        topic_page.visit_topic(topic)
        topic_page.click_post_author_avatar(first_post_by_another_user)

        expect(user_card).to be_showing_user(another_user.username)
        expect(user_card).to have_inactive_user
        expect(user_card).to have_filter_button
        expect(user_card.filter_button_text).to match(I18n.t("js.topic.filter_to", count: 2))
      end
    end
  end
end
