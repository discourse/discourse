# frozen_string_literal: true

RSpec.describe "Chat exports", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    Jobs.run_immediately!
    sign_in(current_user)
    chat_system_bootstrap
  end

  after do
    # fixme clean the downloads folder
  end

  it "exports chat messages" do
    message = Fabricate(:chat_message)

    visit "/admin/plugins/chat"
    click_button "Create export"
    click_button "OK"

    visit "/u/#{current_user.username}/messages"
    click_link "[Chat Message] Data export complete"
    click_link "chat-message-"

    sleep 3 # fixme try to get rid of sleep

    file_name = find("a.attachment").text

    assert File.exist?("tmp/downloads/#{file_name}") # use expect

    csv_path = extract_zip("tmp/downloads/#{file_name}", "tmp/downloads/")
    data = CSV.read(csv_path)

    expect(data[0]).to match_array(
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
    expect(data_row[0]).to eq(message.id.to_s)
    expect(data_row[1]).to eq(message.chat_channel.id.to_s)
    expect(data_row[2]).to eq(message.chat_channel.name)
    expect(data_row[3]).to eq(message.user.id.to_s)
    expect(data_row[4]).to eq(message.user.username)
    expect(data_row[5]).to eq(message.message)
    expect(data_row[6]).to eq(message.cooked)
    # expect(Time.parse(data_row[7])).to eq_time(message.created_at)
    # expect(Time.parse(data_row[8])).to eq_time(message.updated_at)
    # expect(Time.parse(data_row[9])).to eq_time(message.deleted_at)
    # expect(data_row[10]).to eq(message.in_reply_to_id.to_s)
    expect(data_row[11]).to eq(message.last_editor.id.to_s)
    expect(data_row[12]).to eq(message.last_editor.username)
  end

  it "exports user list" do
    visit("admin/users/list/active")
    expect(page).to have_current_path("/latest")
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
