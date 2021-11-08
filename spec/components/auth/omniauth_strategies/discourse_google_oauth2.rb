# frozen_string_literal: true

require 'rails_helper'

describe OmniAuth::Strategies::DiscourseGoogleOauth2 do
  let(:response_hash) do
    {
      email: 'user@domain.com',
      email_verified: true
    }
  end
  let(:groups) do
    [
      {
        id: "12345",
        name: "group1"
      },
      {
        id: "67890",
        name: "group2"
      }
    ]
  end
  let(:uid) { "12345" }
  let(:domain) { "domain.com" }

  def build_response(body)
    [200, { 'Content-Type' => 'application/json' }, body.to_json]
  end

  let(:client) do
    OAuth2::Client.new('abc', 'def') do |builder|
      builder.request :url_encoded
      builder.adapter :test do |stub|
        stub.get('/oauth2/v3/userinfo') { build_response(response_hash) }
        stub.get(described_class::GROUPS_PATH) { build_response(groups: groups) }
      end
    end
  end
  let(:access_token) { OAuth2::AccessToken.from_hash(client, {}) }

  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end

  before do
    @options = {}
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  subject do
    strategy = described_class.new(app, 'appid', 'secret', @options)
    strategy.stubs(:uid).returns(uid)
    strategy.stubs(:access_token).returns(access_token)
    strategy
  end

  it 'should not include users groups when request_groups is not true' do
    expect(subject.extra).not_to have_key(:raw_groups)
  end

  it 'should include users groups when request_groups is true' do
    @options[:request_groups] = true
    expect(subject.extra[:raw_groups].map(&:symbolize_keys)).to eq(groups)
  end
end
