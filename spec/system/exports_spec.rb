# frozen_string_literal: true

RSpec.describe "Exports", type: :system do
  fab!(:admin) do
    Fabricate(
      :admin,
      title: "dr",
      last_seen_at: Time.now,
      last_posted_at: Time.now,
      last_emailed_at: Time.now,
      suspended_at: Time.now,
      suspended_till: Time.now,
      silenced_till: Time.now,
    )
  end

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  after { Downloads.clear }

  it "exports user list" do
    visit "admin/users/list/active"
    click_button "Export"
    click_button "OK" # fixme maybe remove this

    visit "/u/#{admin.username}/messages"
    click_link "[User List] Data export complete"
    click_link "user-list-"

    sleep 3 # fixme try to get rid of sleep

    file_name = find("a.attachment").text

    expect(File.exist?("#{Downloads::FOLDER}/#{file_name}")).to be_truthy

    csv_path = extract_zip("#{Downloads::FOLDER}/#{file_name}", Downloads::FOLDER)
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

    expect(data.length).to be(4)

    exported_admin = data[3]
    time_format = "%Y-%m-%d %k:%M:%S UTC"
    expect(exported_admin).to eq(
      [
        admin.id.to_s,
        admin.name,
        admin.username,
        admin.email,
        admin.title,
        admin.created_at.strftime(time_format),
        admin.updated_at.strftime(time_format),
        admin.created_at.strftime(time_format),
        admin.last_seen_at.strftime(time_format),
        admin.last_posted_at.strftime(time_format),
        admin.last_emailed_at.strftime(time_format),
        admin.trust_level,
        admin.approved,
        admin.suspended_at.strftime(time_format),
        admin.suspended_till.strftime(time_format),
        admin.silenced_till.strftime(time_format),
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
