require 'rails_helper'

describe BasicGroupSerializer do
  let(:guardian) { Guardian.new }
  let(:group) { Fabricate(:group) }
  subject { described_class.new(group, scope: guardian, root: false) }

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

    subject do
      described_class.new(group, scope: guardian, root: false, owner_group_ids: [group.id])
    end

    describe 'group owner' do
      let(:user) do
        user = Fabricate(:user)
        group.add_owner(user)
        user
      end

      it 'should include bio_raw' do
        expect(subject.as_json[:bio_raw]).to eq('testing')
      end
    end
  end

  describe '#has_messages' do
    let(:group) { Fabricate(:group, has_messages: true) }

    describe 'for a staff user' do
      let(:guardian) { Guardian.new(Fabricate(:moderator)) }

      it 'should be present' do
        expect(subject.as_json[:has_messages]).to eq(true)
      end
    end

    describe 'for a group user' do
      let(:user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(user) }

      before do
        group.add(user)
      end

      it 'should be present' do
        expect(subject.as_json[:has_messages]).to eq(true)
      end
    end

    describe 'for a normal user' do
      let(:guardian) { Guardian.new(Fabricate(:user)) }

      it 'should not be present' do
        expect(subject.as_json[:has_messages]).to eq(nil)
      end
    end
  end
end
