# frozen_string_literal: true

describe "Private Message", type: :system do
  let(:sender) { Fabricate(:user) }
  let(:recipient) { Fabricate(:user) }

  let(:post) { Fabricate(:private_message_post, user: sender, recipient: recipient) }

  before { sign_in(recipient) }

  context "when being removed from private conversation" do
    it "redirects away from the private message" do
      visit(post.full_url)

      expect(page).to have_css("h1", text: post.topic.title)

      post.topic.remove_allowed_user(sender, recipient)

      expect(page).to have_no_css("h1", text: post.topic.title)
      expect(page).to have_current_path("/u/#{recipient.username}/messages")
    end
  end
end
