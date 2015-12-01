# encoding: utf-8
require 'rails_helper'
require_dependency 'api_key'

describe ApiKey do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :created_by }

  it { is_expected.to validate_presence_of :key }

  skip 'validates uniqueness of user_id' do
    Fabricate(:api_key)
    is_expected.to validate_uniqueness_of(:user_id)
  end

end
