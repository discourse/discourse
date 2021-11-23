# frozen_string_literal: true

require 'rails_helper'

describe Auth::OmniAuthStrategies::DiscourseGoogleOauth2 do
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

  def build_response(body, code = 200)
    [code, { 'Content-Type' => 'application/json' }, body.to_json]
  end

  def build_client(groups_response)
    OAuth2::Client.new('abc', 'def') do |builder|
      builder.request :url_encoded
      builder.adapter :test do |stub|
        stub.get('/oauth2/v3/userinfo') { build_response(response_hash) }
        stub.get(described_class::GROUPS_PATH) { groups_response }
      end
    end
  end

  let(:successful_groups_client) do
    build_client(
      build_response(
        groups: groups
      )
    )
  end

  let(:unsuccessful_groups_client) do
    build_client(
      build_response(
        error: {
          code: 403,
          message: "Not Authorized to access this resource/api"
        }
      )
    )
  end

  let(:successful_groups_token) do
    OAuth2::AccessToken.from_hash(successful_groups_client, {})
  end

  let(:unsuccessful_groups_token) do
    OAuth2::AccessToken.from_hash(unsuccessful_groups_client, {})
  end

  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end

  def build_strategy(access_token)
    strategy = described_class.new(app, 'appid', 'secret', @options)
    strategy.stubs(:uid).returns(uid)
    strategy.stubs(:access_token).returns(access_token)
    strategy
  end

  before do
    @options = {}
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  context 'request_groups is true' do
    before do
      @options[:request_groups] = true
    end

    context 'groups request successful' do
      before do
        @strategy = build_strategy(successful_groups_token)
      end

      it 'should include users groups' do
        expect(@strategy.extra[:raw_groups].map(&:symbolize_keys)).to eq(groups)
      end
    end

    context 'groups request unsuccessful' do
      before do
        @strategy = build_strategy(unsuccessful_groups_token)
      end

      it 'users groups should be empty' do
        expect(@strategy.extra[:raw_groups].empty?).to eq(true)
      end
    end
  end

  context 'request_groups is not true' do
    before do
      @options[:request_groups] = false
      @strategy = build_strategy(successful_groups_token)
    end

    it 'should not include users groups' do
      expect(@strategy.extra).not_to have_key(:raw_groups)
    end
  end
end
