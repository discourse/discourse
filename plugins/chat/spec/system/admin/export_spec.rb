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

    extract_zip("tmp/downloads/#{file_name}", "tmp/downloads/")

    headers = CSV.open(file, "r") { |csv| csv.first.to_s }
    assert_equal(
      headers,
      "[\"id\", \"name\", \"partner_type_id\", \"parent_id\", \"phone\", \"website\"]",
      "Header does not match",
    )
  end

  it "exports user list" do
    visit("admin/users/list/active")
    expect(page).to have_current_path("/latest")
  end

  def extract_zip(file, destination)
    FileUtils.mkdir_p(destination)

    Zip::File.open(file) do |zip_file|
      zip_file.each do |f|
        path = File.join(destination, f.name)
        zip_file.extract(f, path) unless File.exist?(path)
      end
    end
  end
end
