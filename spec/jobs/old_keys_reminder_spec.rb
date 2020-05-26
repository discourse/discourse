# frozen_string_literal: true

require "rails_helper"

describe Jobs::OldKeysReminder do
  let!(:google_secret) { SiteSetting.create!(name: 'google_oauth2_client_secret', value: '123', data_type: 1) }
  let!(:instagram_secret) { SiteSetting.create!(name: 'instagram_consumer_secret', value: '123', data_type: 1) }
  let!(:api_key) { Fabricate(:api_key, description: 'api key description') }
  let!(:admin) { Fabricate(:admin) }

  let!(:recent_twitter_secret) { SiteSetting.create!(name: 'twitter_consumer_secret', value: '123', data_type: 1, updated_at: 2.years.from_now) }
  let!(:recent_api_key) { Fabricate(:api_key, description: 'recent api key description', created_at: 2.years.from_now) }

  it 'sends message to admin with old credentials' do
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(1)
    post = Post.last
    expect(post.archetype).to eq(Archetype.private_message)
    expect(post.topic.topic_allowed_users.map(&:user_id).sort).to eq([Discourse.system_user.id, admin.id].sort)
    expect(post.topic.title).to eq("You have 3 old credentials")
    expect(post.raw).to eq(<<-MSG.rstrip)
We have detected you have the following credentials that are 2 years or older

google_oauth2_client_secret - #{google_secret.updated_at}
instagram_consumer_secret - #{instagram_secret.updated_at}
api key description - #{api_key.created_at}

These credentials are sensitive and we recommend resetting them every 2 years to avoid impact of any future data breaches
    MSG

    freeze_time 4.years.from_now
    described_class.new.execute({})
    post = Post.last
    expect(post.topic.title).to eq("You have 5 old credentials")
    expect(post.raw).to eq(<<-MSG.rstrip)
We have detected you have the following credentials that are 2 years or older

google_oauth2_client_secret - #{google_secret.updated_at}
instagram_consumer_secret - #{instagram_secret.updated_at}
twitter_consumer_secret - #{recent_twitter_secret.updated_at}
api key description - #{api_key.created_at}
recent api key description - #{recent_api_key.created_at}

These credentials are sensitive and we recommend resetting them every 2 years to avoid impact of any future data breaches
    MSG
  end

  it 'does not send message when notification set to never or no old keys' do
    SiteSetting.notify_about_secrets_older_than = "never"
    freeze_time 2.years.from_now
    expect { described_class.new.execute({}) }.to change { Post.count }.by(0)
    SiteSetting.notify_about_secrets_older_than = "3 years"
    expect { described_class.new.execute({}) }.to change { Post.count }.by(0)
  end
end
