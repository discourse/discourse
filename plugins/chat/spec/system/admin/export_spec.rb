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
    visit "/admin/plugins/chat"
    click_button "Create export"
    click_button "OK"

    visit "/u/#{current_user.username}/messages"
    click_link "[Chat Message] Data export complete"
    click_link "chat-message-"

    sleep 3 # fixme try to get rid of sleep

    file_name = find("a.attachment").text

    # DOWNLOAD_PATH = Rails.root.join("tmp/downloads").to_s
    # full_path = DOWNLOAD_PATH + "/partners-#{Date.today}.csv"
    assert File.exist?("tmp/downloads/#{file_name}")

    csv_path = extract_zip("tmp/downloads/#{file_name}", "tmp/downloads/")

    data = CSV.read(csv_path, headers: true)

    assert_equal(
      data.headers,
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
      "Headers does not match",
    )
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
