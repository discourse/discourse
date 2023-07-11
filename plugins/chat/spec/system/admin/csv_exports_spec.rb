# frozen_string_literal: true

RSpec.describe "Chat CSV exports", type: :system do
  fab!(:admin) { Fabricate(:admin) }
  let(:csv_export_pm_page) { PageObjects::Pages::CSVExportPM.new }

  before do
    Jobs.run_immediately!
    sign_in(admin)
    chat_system_bootstrap
  end

  xit "exports chat messages" do
    message = Fabricate(:chat_message)

    visit "/admin/plugins/chat"
    click_button "Create export"

    visit "/u/#{admin.username}/messages"
    click_link "[Chat Message] Data export complete"
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

    time_format = "%Y-%m-%d %H:%M:%S UTC"
    expect(exported_data.second).to eq(
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
  ensure
    csv_export_pm_page.clear_downloads
  end
end
