require 'spec_helper'
require_dependency 'badge_type'

describe BadgeType do

  it { should validate_presence_of :name }
  it { should validate_uniqueness_of :name }

end
