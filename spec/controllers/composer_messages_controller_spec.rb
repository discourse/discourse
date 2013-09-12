require 'spec_helper'

describe ComposerMessagesController do

  context '.index' do

    it 'requires you to be logged in' do
      lambda { xhr :get, :index }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      let!(:user) { log_in }
      let(:args) { {'topic_id' => '123', 'post_id' => '333', 'composerAction' => 'reply'} }

      it 'redirects to your user preferences' do
        xhr :get, :index
        response.should be_success
      end

      it 'delegates args to the finder' do
        finder = mock
        ComposerMessagesFinder.expects(:new).with(instance_of(User), has_entries(args)).returns(finder)
        finder.expects(:find)
        xhr :get, :index, args
      end

    end

  end

end

