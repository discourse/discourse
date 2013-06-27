require 'spec_helper'

describe UserOpenId do

  it { should belong_to :user }
  it { should validate_presence_of :email }
  it { should validate_presence_of :url }
end
