# frozen_string_literal: true

RSpec.describe Jobs::OldKeysReminder do
  let!(:google_secret) do
    SiteSetting.create!(name: "google_oauth2_client_secret", value: "123", data_type: 1)
  end
  let!(:github_secret) do
    SiteSetting.create!(name: "github_client_secret", value: "123", data_type: 1)
  end
  let!(:api_key) { Fabricate(:api_key, description: "api key description") }
  let!(:admin) { Fabricate(:admin) }
  let!(:another_admin) { Fabricate(:admin) }

  let!(:recent_twitter_secret) do
    SiteSetting.create!(
      name: "twitter_consumer_secret",
      value: "123",
      data_type: 1,
      updated_at: 2.years.from_now,
    )
  end
  let!(:recent_api_key) do
    Fabricate(
      :api_key,
      description: "recent api key description",
      created_at: 2.years.from_now,
      user_id: admin.id,
    )
  end

  it "is disabled be default" do
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.not_to change { Post.count }
  end

  it "sends message to admin with old credentials" do
    SiteSetting.send_old_credential_reminder_days = "365"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(1)
    post = Post.last
    expect(post.archetype).to eq(Archetype.private_message)
    expect(post.topic.topic_allowed_users.map(&:user_id).sort).to eq(
      [Discourse.system_user.id, admin.id, another_admin.id].sort,
    )
    expect(post.topic.title).to eq("Reminder about old credentials")
    expect(post.raw).to eq(<<~TEXT.rstrip)
      Hello! This is a routine yearly security reminder from your Discourse instance.

      As a courtesy, we wanted to let you know that the following credentials used on your Discourse instance have not been updated in more than two years:

      google_oauth2_client_secret - #{google_secret.updated_at.to_date.to_fs(:db)}
      github_client_secret - #{github_secret.updated_at.to_date.to_fs(:db)}
      api key description - #{api_key.created_at.to_date.to_fs(:db)}

      No action is required at this time, however, it is considered good security practice to cycle all your important credentials every few years.
    TEXT

    post.topic.destroy
    freeze_time 4.years.from_now
    described_class.new.execute({})
    post = Post.last
    expect(post.topic.title).to eq("Reminder about old credentials")
    expect(post.raw).to eq(<<~TEXT.rstrip)
      Hello! This is a routine yearly security reminder from your Discourse instance.

      As a courtesy, we wanted to let you know that the following credentials used on your Discourse instance have not been updated in more than two years:

      google_oauth2_client_secret - #{google_secret.updated_at.to_date.to_fs(:db)}
      github_client_secret - #{github_secret.updated_at.to_date.to_fs(:db)}
      twitter_consumer_secret - #{recent_twitter_secret.updated_at.to_date.to_fs(:db)}
      api key description - #{api_key.created_at.to_date.to_fs(:db)}
      recent api key description - #{admin.username} - #{recent_api_key.created_at.to_date.to_fs(:db)}

      No action is required at this time, however, it is considered good security practice to cycle all your important credentials every few years.
    TEXT
  end

  it "does not send message when send_old_credential_reminder_days is set to 0 or no old keys" do
    expect { described_class.new.execute({}) }.not_to change { Post.count }
    SiteSetting.send_old_credential_reminder_days = "0"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.not_to change { Post.count }
  end

  it "does not send a message if already exists" do
    SiteSetting.send_old_credential_reminder_days = "367"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(1)
    Topic.last.trash!
    expect { described_class.new.execute({}) }.not_to change { Post.count }
    freeze_time 1.years.from_now
    expect { described_class.new.execute({}) }.not_to change { Post.count }
    freeze_time 3.days.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(1)
  end
end
