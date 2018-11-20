require 'rails_helper'

describe SpamRulesEnforcer do

  before do
    SystemMessage.stubs(:create)
  end

  describe 'enforce!' do
    context 'post argument' do
      subject(:enforce) { described_class.enforce!(Fabricate.build(:post)) }

      it 'performs the FlagSockpuppetRule' do
        SpamRule::FlagSockpuppets.any_instance.expects(:perform).once
        enforce
      end
    end

    context 'user argument' do
      subject(:enforce) { described_class.enforce!(Fabricate.build(:user)) }

      it 'performs the AutoSilence' do
        SpamRule::AutoSilence.any_instance.expects(:perform).once
        enforce
      end
    end
  end

end
