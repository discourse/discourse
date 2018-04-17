require 'rails_helper'

describe BasicGroupSerializer do
  let(:guardian) { Guardian.new }
  let(:group) { Fabricate(:group) }
  subject { described_class.new(group, scope: Guardian.new, root: false) }

  describe '#display_name' do
    describe 'automatic group' do
      let(:group) { Group.find(1) }

      it 'should include the display name' do
        expect(subject.display_name).to eq(I18n.t('groups.default_names.admins'))
      end
    end

    describe 'normal group' do
      let(:group) { Fabricate(:group) }

      it 'should not include the display name' do
        expect(subject.display_name).to eq(nil)
      end
    end
  end

  describe '#bio_raw' do
    let(:group) { Fabricate(:group, bio_raw: 'testing') }

    let(:user) do
      user = Fabricate(:user)
      group.add_owner(user)
      user
    end

    let(:guardian) { Guardian.new(user) }

    describe 'group owner' do
      it 'should include bio_raw' do
        expect(subject.bio_raw).to eq('testing')
      end
    end
  end
end
