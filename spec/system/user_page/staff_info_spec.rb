# frozen_string_literal: true

describe "Viewing user staff info as an admin", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:user_page) { PageObjects::Pages::User.new }

  before { sign_in(admin) }

  context "for warnings" do
    fab!(:topic) { Fabricate(:private_message_topic, user: admin, recipient: user) }
    fab!(:user_warning) { UserWarning.create!(user: user, created_by: admin, topic: topic) }

    it "should display the right link to user's warnings with the right count in text" do
      user_page.visit(user).click_staff_info_warnings_link(user, warnings_count: 1)

      expect(user_page).to have_warning_messages_path(user)
    end
  end
end
