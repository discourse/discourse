# frozen_string_literal: true

describe "Viewing user staff info as an admin", type: :system do
  fab!(:user)
  fab!(:admin)
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

  context "for silencings" do
    fab!(:silencing) do
      Fabricate(:user_history, action: UserHistory.actions[:silence_user], target_user: user)
    end
    it "should display the right link to user's silencings with the right count in text" do
      user_page.visit(user)
      silencings_counters = page.find(".staff-counters .silencings")
      expect(silencings_counters).to have_text("1")

      user_page.click_staff_info_silencings_link
      expect(user_page).to have_current_path("/admin/logs/staff_action_logs", ignore_query: true)

      current_url = user_page.current_url
      uri = URI.parse(current_url)
      filters = JSON.parse(URI.decode_www_form(uri.query).to_h["filters"])

      expect(filters["target_user"]).to eq(user.username)
      expect(filters["action_name"]).to eq("silence_user")
    end
  end
end
