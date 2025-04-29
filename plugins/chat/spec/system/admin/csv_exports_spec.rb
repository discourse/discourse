# frozen_string_literal: true

RSpec.describe "Admin Chat CSV exports", type: :system do
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:csv_export_pm_page) { PageObjects::Pages::CSVExportPM.new }
  fab!(:current_user) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(current_user)
    chat_system_bootstrap
  end

  it "exports chat messages" do
    orignal_save_path = Capybara.save_path
    Capybara.save_path = Downloads::FOLDER

    Jobs.run_immediately!
    message_1 = Fabricate(:chat_message, created_at: 12.months.ago)
    message_2 = Fabricate(:chat_message, created_at: 6.months.ago)
    message_3 = Fabricate(:chat_message, created_at: 1.months.ago)
    message_4 = Fabricate(:chat_message, created_at: Time.now)

    visit "/admin/plugins/chat"
    click_button I18n.t("js.chat.admin.export_messages.create_export")
    dialog.click_yes

    visit "/u/#{current_user.username}/messages"
    click_link I18n.t(
                 "system_messages.csv_export_succeeded.subject_template",
                 export_title: "Chat Message",
               )
    expect(csv_export_pm_page).to have_download_link
    exported_data = csv_export_pm_page.download_and_extract

    expect(exported_data.first).to eq(
      %w[
        id
        chat_channel_id
        chat_channel_name
        user_id
        username
        message
        cooked
        created_at
        updated_at
        deleted_at
        in_reply_to_id
        last_editor_id
        last_editor_username
      ],
    )

    assert_message(exported_data.second, message_1)
    assert_message(exported_data.third, message_2)
    assert_message(exported_data.fourth, message_3)
    assert_message(exported_data.fifth, message_4)
  ensure
    Capybara.save_path = orignal_save_path
    csv_export_pm_page.clear_downloads
  end

  def assert_message(exported_message, message)
    time_format = "%Y-%m-%d %H:%M:%S UTC"
    expect(exported_message).to eq(
      [
        message.id.to_s,
        message.chat_channel.id.to_s,
        message.chat_channel.name,
        message.user.id.to_s,
        message.user.username,
        message.message,
        message.cooked,
        message.created_at.strftime(time_format),
        message.updated_at.strftime(time_format),
        nil,
        nil,
        message.last_editor.id.to_s,
        message.last_editor.username,
      ],
    )
  end
end
