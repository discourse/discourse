require 'rails_helper'

describe UserOpenId do

  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :email }
  it { is_expected.to validate_presence_of :url }
end
