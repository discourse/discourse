require 'spec_helper'

describe DraftController do

  it 'requires you to be logged in' do
    lambda { post :update }.should raise_error(Discourse::NotLoggedIn)
  end

  it 'saves a draft on update' do
    user = log_in
    post :update, draft_key: 'xyz', data: 'my data', sequence: 0
    Draft.get(user, 'xyz', 0).should == 'my data'
  end

  it 'destroys drafts when required' do
    user = log_in
    Draft.set(user, 'xxx', 0, 'hi')
    delete :destroy, draft_key: 'xxx', sequence: 0
    Draft.get(user, 'xxx', 0).should == nil
  end

end
