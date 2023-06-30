# frozen_string_literal: true

RSpec.describe "Chat exports", type: :system do
  fab!(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
    chat_system_bootstrap
  end

  after do
    # fixme clean the downloads folder
  end

  it "exports chat messages" do
    message = Fabricate(:chat_message)

    visit "/admin/plugins/chat"
    click_button "Create export"
    click_button "OK" # fixme maybe remove this

    visit "/u/#{admin.username}/messages"
    click_link "[Chat Message] Data export complete"
    click_link "chat-message-"

    sleep 3 # fixme try to get rid of sleep

    file_name = find("a.attachment").text

    expect(File.exist?("tmp/downloads/#{file_name}")).to be_truthy

    csv_path = extract_zip("tmp/downloads/#{file_name}", "tmp/downloads/")
    data = CSV.read(csv_path)

    expect(data[0]).to eq(
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

    data_row = data[1]
    time_format = "%Y-%m-%d %k:%M:%S UTC"
    expect(data_row).to eq(
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

  def extract_zip(file, destination)
    FileUtils.mkdir_p(destination)

    path = ""
    Zip::File.open(file) do |zip_files|
      csv_file = zip_files.first
      path = File.join(destination, csv_file.name)
      zip_files.extract(csv_file, path) unless File.exist?(path)
    end

    path
  end
end
