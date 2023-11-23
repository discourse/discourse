# frozen_string_literal: true

RSpec.describe UserAuthTokenSerializer do
  fab!(:user) { Fabricate(:moderator) }
  let(:token) { UserAuthToken.generate!(user_id: user.id, client_ip: "2a02:ea00::", staff: true) }
  # Assign a dummy MaxMind license key, which is now checked in open_db
  global_setting "maxmind_license_key", "dummy"

  before(:each) { DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb")) }

  it "serializes user auth tokens with respect to user locale" do
    I18n.locale = "de"
    json = UserAuthTokenSerializer.new(token, scope: Guardian.new(user), root: false).as_json
    expect(json[:location]).to include("Schweiz")
  end

  it "correctly translates Discourse locale to MaxMindDb locale" do
    I18n.locale = "zh_CN"
    json = UserAuthTokenSerializer.new(token, scope: Guardian.new(user), root: false).as_json
    expect(json[:location]).to include("瑞士")
  end
end
