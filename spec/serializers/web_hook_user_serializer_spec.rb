# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebHookUserSerializer do
  let(:user) do
    user = Fabricate(:user)
    SingleSignOnRecord.create!(user_id: user.id, external_id: '12345', last_payload: '')
    user
  end

  fab!(:admin) { Fabricate(:admin) }

  let :serializer do
    WebHookUserSerializer.new(user, scope: Guardian.new(admin), root: false)
  end

  it "should include relevant user info" do
    payload = serializer.as_json
    expect(payload[:email]).to eq(user.email)
    expect(payload[:external_id]).to eq('12345')
  end

  it 'should only include the required keys' do
    count = serializer.as_json.keys.count
    difference = count - 42

    expect(difference).to eq(0), lambda {
      message = ""

      if difference < 0
        message << "#{difference * -1} key(s) have been removed from this serializer."
      else
        message << "#{difference} key(s) have been added to this serializer."
      end

      message << "\nPlease verify if those key(s) are required as part of the web hook's payload."
    }
  end

  it 'should exclude attributes that depend on the user profile' do
    included_attrs = serializer.as_json.keys

    %i[bio_raw website location bio_excerpt profile_view_count].each do |attr|
      expect(included_attrs).not_to include(attr)
    end
  end
end
