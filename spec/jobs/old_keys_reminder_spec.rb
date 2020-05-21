# frozen_string_literal: true

require "rails_helper"

describe Jobs::OldKeysReminder do
  let!(:google_secret) { SiteSetting.create!(name: 'google_oauth2_client_secret', value: '123', data_type: 1) }
  let!(:instagram_secret) { SiteSetting.create!(name: 'instagram_consumer_secret', value: '123', data_type: 1) }
  let!(:api_key) { Fabricate(:api_key, description: 'api key description') }
  let!(:admin) { Fabricate(:admin) }

  it "detects old keys" do
    SiteSetting.notify_about_secrets_older_than = "2 years"
    freeze_time 2.years.from_now
    expect(described_class.new.send(:old_site_settings_keys).sort).to eq([google_secret, instagram_secret].sort)
    expect(described_class.new.send(:old_api_keys)).to eq([api_key])
    SiteSetting.notify_about_secrets_older_than = "3 years"
    expect(described_class.new.send(:old_site_settings_keys)).to eq([])
    expect(described_class.new.send(:old_api_keys)).to eq([])
  end

  it 'has correct title' do
    SiteSetting.notify_about_secrets_older_than = "2 years"
    freeze_time 2.years.from_now
    expect(described_class.new.send(:title)).to eq("You have 3 old credentials")
  end

  it 'has correct body' do
    SiteSetting.notify_about_secrets_older_than = "2 years"
    freeze_time 2.years.from_now
    expect(described_class.new.send(:body)).to eq(<<-MSG)
We have detected you have the following credentials that are 2 years or older

google_oauth2_client_secret - #{google_secret.updated_at}
instagram_consumer_secret - #{instagram_secret.updated_at}
api key description - #{api_key.created_at}

These credentials are sensitive and we recommend resetting them every 2 years to avoid impact of any future data breaches
    MSG
  end

  it 'sends message to admin' do
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(1)
    post = Post.last
    expect(post.archetype).to eq(Archetype.private_message)
    expect(post.topic.topic_allowed_users.map(&:user_id).sort).to eq([Discourse.system_user.id, admin.id].sort)
  end

  it 'does not send message when notification set to never or no old keys' do
    SiteSetting.notify_about_secrets_older_than = "never"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(0)
    SiteSetting.notify_about_secrets_older_than = "never"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(0)
  end
end
