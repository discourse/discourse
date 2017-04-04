require 'rails_helper'

RSpec.describe WebHookUserSerializer do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  subject { described_class.new(user, scope: Guardian.new(admin), root: false) }

  it "should include the user's email" do
    payload = subject.as_json

    expect(payload[:email]).to eq(user.email)
  end
end
