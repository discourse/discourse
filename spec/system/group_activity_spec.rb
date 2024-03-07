# frozen_string_literal: true

describe "Group activity", type: :system do
  fab!(:user)
  fab!(:group)

  context "when on the posts activity page" do
    let(:posts_page) { PageObjects::Pages::GroupActivityPosts.new }

    before do
      group.add(user)
      sign_in(user)

      40.times { Fabricate(:post, user: user, topic: Fabricate(:topic, user: user)) }

      # higher id, older post
      older_post =
        Fabricate(:post, user: user, topic: Fabricate(:topic, user: user), raw: "older post")
      older_post.update!(created_at: 1.day.ago)
    end

    it "loads and paginates the results by chronology" do
      posts_page.visit(group)

      expect(posts_page).to have_user_stream_item(count: 20)
      expect(posts_page).not_to have_content("older post")

      posts_page.scroll_to_last_item

      expect(posts_page).to have_user_stream_item(count: 40)
      expect(posts_page).not_to have_content("older post")

      posts_page.scroll_to_last_item

      expect(posts_page).to have_content("older post")
      expect(posts_page).to have_user_stream_item(count: 41)
    end
  end
end
