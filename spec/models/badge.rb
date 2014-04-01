require 'spec_helper'
require_dependency 'badge'

describe Badge do

  it { should belong_to :badge_type }
  it { should have_many(:user_badges).dependent(:destroy) }

  context 'validations' do
    before(:each) { Fabricate(:badge) }

    it { should validate_presence_of :name }
    it { should validate_presence_of :badge_type }
    it { should validate_uniqueness_of :name }
  end

end

