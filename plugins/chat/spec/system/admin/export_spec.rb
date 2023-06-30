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
    click_button "OK" # fixme maybe remove this

    visit "/u/#{current_user.username}/messages"
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

  it "exports user list" do
    visit "admin/users/list/active"
    click_button "Export"
    click_button "OK" # fixme maybe remove this

    visit "/u/#{current_user.username}/messages"
    click_link "[User List] Data export complete"
    click_link "user-list-"

    sleep 3 # fixme try to get rid of sleep

    file_name = find("a.attachment").text

    expect(File.exist?("tmp/downloads/#{file_name}")).to be_truthy

    csv_path = extract_zip("tmp/downloads/#{file_name}", "tmp/downloads/")
    data = CSV.read(csv_path)

    expect(data[0]).to eq(
      %w[
        id
        name
        username
        email
        title
        created_at
        last_seen_at
        last_posted_at
        last_emailed_at
        trust_level
        approved
        suspended_at
        suspended_till
        silenced_till
        active
        admin
        moderator
        ip_address
        staged
        secondary_emails
        topics_entered
        posts_read_count
        time_read
        topic_count
        post_count
        likes_given
        likes_received
        location
        website
        views
        group_names
      ],
    )

    data_row = data[1]
    time_format = "%Y-%m-%d %k:%M:%S UTC"
    # fixme implement
    # expect(data_row).to eq(
    #   [
    #     message.id.to_s,
    #     message.chat_channel.id.to_s,
    #     message.chat_channel.name,
    #     message.user.id.to_s,
    #     message.user.username,
    #     message.message,
    #     message.cooked,
    #     message.created_at.strftime(time_format),
    #     message.updated_at.strftime(time_format),
    #     nil,
    #     nil,
    #     message.last_editor.id.to_s,
    #     message.last_editor.username,
    #   ],
    # )
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
