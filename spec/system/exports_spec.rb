# frozen_string_literal: true

RSpec.describe "Exports", type: :system do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:group1) { Fabricate(:group) }
  fab!(:group2) { Fabricate(:group) }
  fab!(:user) do
    Fabricate(
      :user,
      title: "dr",
      last_seen_at: Time.now,
      last_posted_at: Time.now,
      last_emailed_at: Time.now,
      approved: true,
      suspended_at: Time.now,
      suspended_till: Time.now,
      silenced_till: Time.now,
      admin: true,
      moderator: true,
      staged: true,
      group_ids: [group1.id, group2.id],
    )
  end
  let(:second_email) { "second_email@discourse.org" }
  let(:third_email) { "third_email@discourse.org" }

  before do
    Jobs.run_immediately!
    sign_in(admin)

    user.user_emails.create!(email: second_email)
    user.user_emails.create!(email: third_email)

    user.user_stat.topics_entered = 111
    user.user_stat.posts_read_count = 112
    user.user_stat.time_read = 113
    user.user_stat.topic_count = 114
    user.user_stat.post_count = 115
    user.user_stat.likes_given = 116
    user.user_stat.likes_received = 117
    user.user_stat.save!

    user.user_profile.location = "Tbilisi"
    user.user_profile.website = "https://www.discourse.org"
    user.user_profile.views = 5
    user.user_profile.save!
  end

  after { Downloads.clear }

  it "exports user list" do
    visit "admin/users/list/active"
    click_button "Export"

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

    expect(data.length).to be(5)

    exported_admin = data[4]
    time_format = "%Y-%m-%d %k:%M:%S UTC"
    expect(exported_admin).to eq(
      [
        user.id.to_s,
        user.name,
        user.username,
        user.email,
        user.title,
        user.created_at.strftime(time_format),
        user.last_seen_at.strftime(time_format),
        user.last_posted_at.strftime(time_format),
        user.last_emailed_at.strftime(time_format),
        user.trust_level.to_s,
        user.approved.to_s,
        user.suspended_at.strftime(time_format),
        user.suspended_till.strftime(time_format),
        user.silenced_till.strftime(time_format),
        user.active.to_s,
        user.admin.to_s,
        user.moderator.to_s,
        user.ip_address.to_s,
        user.staged.to_s,
        "#{second_email};#{third_email}",
        user.user_stat.topics_entered.to_s,
        user.user_stat.posts_read_count.to_s,
        user.user_stat.time_read.to_s,
        user.user_stat.topic_count.to_s,
        user.user_stat.post_count.to_s,
        user.user_stat.likes_given.to_s,
        user.user_stat.likes_received.to_s,
        user.user_profile.location,
        user.user_profile.website,
        user.user_profile.views.to_s,
        "#{group1.name};#{group2.name}",
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
