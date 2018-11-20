# encoding: utf-8
require 'rails_helper'
require_dependency 'api_key'

describe ApiKey do
  let(:user) { Fabricate(:user) }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :created_by }
  it { is_expected.to validate_presence_of :key }

  it 'validates uniqueness of user_id' do
    Fabricate(:api_key, user: user)
    api_key = Fabricate.build(:api_key, user: user)

    expect(api_key.save).to eq(false)
    expect(api_key.errors).to include(:user_id)
  end

end
