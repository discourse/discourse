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
end
