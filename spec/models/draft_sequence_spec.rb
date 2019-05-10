# frozen_string_literal: true

require 'rails_helper'

describe DraftSequence do
  fab!(:user) { Fabricate(:user) }

  it 'should produce next sequence for a key' do
    expect(DraftSequence.next!(user, 'test')).to eq 1
    expect(DraftSequence.next!(user, 'test')).to eq 2
  end

  describe '.current' do
    it 'should return 0 by default' do
      expect(DraftSequence.current(user, 'test')).to eq 0
    end

    it 'should return the right sequence' do
      expect(DraftSequence.next!(user, 'test')).to eq(1)
      expect(DraftSequence.current(user, 'test')).to eq(1)
    end
  end
end
