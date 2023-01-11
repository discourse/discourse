# encoding: utf-8
# frozen_string_literal: true

RSpec.describe ApiKey do
  fab!(:user) { Fabricate(:user) }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :created_by }

  it "generates a key when saving" do
    api_key = ApiKey.new
    api_key.save!
    initial_key = api_key.key
    expect(initial_key.length).to eq(64)

    # Does not overwrite key when saving again
    api_key.description = "My description here"
    api_key.save!
    expect(api_key.reload.key).to eq(initial_key)
  end

  it "does not have the key when loading later from the database" do
    api_key = ApiKey.create!
    expect(api_key.key_available?).to eq(true)
    expect(api_key.key.length).to eq(64)

    api_key = ApiKey.find(api_key.id)
    expect(api_key.key_available?).to eq(false)
    expect { api_key.key }.to raise_error(ApiKey::KeyAccessError)
  end

  it "can lookup keys based on their hash" do
    key = ApiKey.create!.key
    expect(ApiKey.with_key(key).length).to eq(1)
  end

  it "can calculate the epoch correctly" do
    expect(ApiKey.last_used_epoch.to_datetime).to be_a(DateTime)

    SiteSetting.api_key_last_used_epoch = ""
    expect(ApiKey.last_used_epoch).to eq(nil)
  end

  it "can automatically revoke keys" do
    now = Time.now

    SiteSetting.api_key_last_used_epoch = now - 2.years
    SiteSetting.revoke_api_keys_days = 180 # 6 months

    freeze_time now - 1.year
    never_used = Fabricate(:api_key)
    used_previously = Fabricate(:api_key)
    used_previously.update(last_used_at: Time.zone.now)
    used_recently = Fabricate(:api_key)

    freeze_time now - 3.months
    used_recently.update(last_used_at: Time.zone.now)

    freeze_time now
    ApiKey.revoke_unused_keys!

    [never_used, used_previously, used_recently].each(&:reload)
    expect(never_used.revoked_at).to_not eq(nil)
    expect(used_previously.revoked_at).to_not eq(nil)
    expect(used_recently.revoked_at).to eq(nil)

    # Restore them
    [never_used, used_previously, used_recently].each { |a| a.update(revoked_at: nil) }

    # Move the epoch to 1 month ago
    SiteSetting.api_key_last_used_epoch = now - 1.month
    ApiKey.revoke_unused_keys!

    [never_used, used_previously, used_recently].each(&:reload)
    expect(never_used.revoked_at).to eq(nil)
    expect(used_previously.revoked_at).to eq(nil)
    expect(used_recently.revoked_at).to eq(nil)
  end

  describe "API Key scope mappings" do
    it "maps api_key permissions" do
      api_key_mappings = ApiKeyScope.scope_mappings[:topics]

      assert_responds_to(api_key_mappings.dig(:write, :actions))
      assert_responds_to(api_key_mappings.dig(:read, :actions))
      assert_responds_to(api_key_mappings.dig(:read_lists, :actions))
    end

    def assert_responds_to(mappings)
      mappings.each do |m|
        controller, method = m.split("#")
        controller_name = "#{controller.capitalize}Controller"
        expect(controller_name.constantize.method_defined?(method)).to eq(true)
      end
    end
  end

  describe "#request_allowed?" do
    let(:request) do
      ActionDispatch::TestRequest.create.tap do |request|
        request.path_parameters = { controller: "topics", action: "show", topic_id: "3" }
        request.remote_addr = "133.45.67.99"
      end
    end

    let(:env) { request.env }

    let(:key) { ApiKey.new(api_key_scopes: [scope]) }

    context "with regular scopes" do
      let(:scope) do
        ApiKeyScope.new(resource: "topics", action: "read", allowed_parameters: { topic_id: "3" })
      end

      it "allows the request if there are no allowed IPs" do
        key.allowed_ips = nil
        key.api_key_scopes = []
        expect(key.request_allowed?(env)).to eq(true)
      end

      it "rejects the request if the IP is not allowed" do
        key.allowed_ips = %w[115.65.76.87]
        expect(key.request_allowed?(env)).to eq(false)
      end

      it "allow the request if there are not allowed params" do
        scope.allowed_parameters = nil
        expect(key.request_allowed?(env)).to eq(true)
      end

      it "rejects the request when params are different" do
        request.path_parameters = { controller: "topics", action: "show", topic_id: "4" }
        expect(key.request_allowed?(env)).to eq(false)
      end

      it "accepts the request if one of the parameters match" do
        request.path_parameters = { controller: "topics", action: "show", topic_id: "4" }
        scope.allowed_parameters = { topic_id: %w[3 4] }
        expect(key.request_allowed?(env)).to eq(true)
      end

      it "allow the request when the scope has an alias" do
        request.path_parameters = { controller: "topics", action: "show", id: "3" }
        expect(key.request_allowed?(env)).to eq(true)
      end

      it "rejects the request when the main parameter and the alias are both used" do
        request.path_parameters = { controller: "topics", action: "show", topic_id: "3", id: "3" }
        expect(key.request_allowed?(env)).to eq(false)
      end
    end

    context "with global:read scope" do
      let(:scope) { ApiKeyScope.new(resource: "global", action: "read") }

      it "allows only GET requests for global:read" do
        request.request_method = "GET"
        expect(key.request_allowed?(env)).to eq(true)

        request.request_method = "POST"
        expect(key.request_allowed?(env)).to eq(false)
      end
    end
  end
end
