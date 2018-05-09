require 'rails_helper'

describe BasicGroupSerializer do
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
end
