# encoding: utf-8
require 'spec_helper'
require_dependency 'api_key'

describe ApiKey do
  it { should belong_to :user }
  it { should belong_to :created_by }

  it { should validate_presence_of :key }

  it 'validates uniqueness of user_id' do
    Fabricate(:api_key)
    should validate_uniqueness_of(:user_id)
  end

end
