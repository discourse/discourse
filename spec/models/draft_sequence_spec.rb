require 'spec_helper'

describe DraftSequence do
  it 'should produce next sequence for a key' do
    u = Fabricate(:user)
    DraftSequence.next!(u, 'test').should == 1
    DraftSequence.next!(u, 'test').should == 2
  end

  it 'should return 0 by default' do
    u = Fabricate(:user)
    DraftSequence.current(u, 'test').should == 0
  end
end
