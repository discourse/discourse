require 'spec_helper'

describe NotificationsController do

  context 'when logged in' do
    let!(:user) { log_in }

    before do
      xhr :get, :index
    end

    subject { response }
    it { should be_success }
  end

  context 'when not logged in' do
    it 'should raise an error' do
      lambda { xhr :get, :index }.should raise_error(Discourse::NotLoggedIn)
    end
  end

end
