require 'rails_helper'

describe BasicGroupUserSerializer do
  let(:group) { Fabricate(:group) }
  let(:user) { Fabricate(:user) }

  before do
    group.add(user)
  end

  describe '#owner' do
    describe 'when scoped to the user' do
      it 'should be false' do
        json = described_class.new(
          GroupUser.last,
          scope: Guardian.new(user),
          root: false
        ).as_json

        expect(json[:owner]).to eq(false)
      end
    end

    describe 'when not scoped to the user' do
      it 'should be nil' do
        json = described_class.new(
          GroupUser.last,
          scope: Guardian.new,
          root: false
        ).as_json

        expect(json[:owner]).to eq(nil)
      end
    end
  end
end
