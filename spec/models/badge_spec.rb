require 'spec_helper'
require_dependency 'badge'

describe Badge do

  it 'has a valid system attribute for new badges' do
    Badge.create!(name: "test", badge_type_id: 1).system?.should be_false
  end

end

