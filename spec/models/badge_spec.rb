require 'spec_helper'
require_dependency 'badge'

describe Badge do

  it 'has a valid system attribute for new badges' do
    Badge.new.system?.should be_false
  end

end

