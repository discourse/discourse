require 'rails_helper'

describe DraftSequence do
  it 'should produce next sequence for a key' do
    u = Fabricate(:user)
    expect(DraftSequence.next!(u, 'test')).to eq 1
    expect(DraftSequence.next!(u, 'test')).to eq 2
  end

  it 'should return 0 by default' do
    u = Fabricate(:user)
    expect(DraftSequence.current(u, 'test')).to eq 0
  end
end
