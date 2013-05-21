require 'spec_helper'
require_dependency 'user_destroyer'

describe UserDestroyer do

  before do
    RestClient.stubs(:delete).returns( {success: 'OK'}.to_json )
  end

  describe 'new' do
    it 'raises an error when user is nil' do
      expect { UserDestroyer.new(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { UserDestroyer.new(5) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is a regular user' do
      expect { UserDestroyer.new( Fabricate(:user) ) }.to raise_error(Discourse::InvalidAccess)
    end

    it 'raises an error when user is a moderator' do
      expect { UserDestroyer.new( Fabricate(:moderator) ) }.to raise_error(Discourse::InvalidAccess)
    end

    it 'returns an instance of UserDestroyer when user is an admin' do
      UserDestroyer.new( Fabricate(:admin) ).should be_a(UserDestroyer)
    end
  end

  describe 'destroy' do
    before do
      @admin = Fabricate(:admin)
      @user = Fabricate(:user)
    end

    subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }

    it 'raises an error when user is nil' do
      expect { UserDestroyer.new(@admin).destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { UserDestroyer.new(@admin).destroy('nothing') }.to raise_error(Discourse::InvalidParameters)
    end

    context 'user has posts' do
      before do
        Fabricate(:post, user: @user)
      end

      it 'should not delete the user' do
        expect { destroy rescue nil }.to_not change { User.count }
      end

      it 'should raise an error' do
        expect { destroy }.to raise_error( UserDestroyer::PostsExistError )
      end

      it 'should not log the action' do
        AdminLogger.any_instance.expects(:log_user_deletion).never
        destroy rescue nil
      end

      it 'should not unregister the user at the discourse hub' do
        DiscourseHub.expects(:unregister_nickname).never
        destroy rescue nil
      end
    end

    context 'user has no posts' do
      context 'and destroy succeeds' do
        it 'should delete the user' do
          expect { destroy }.to change { User.count }.by(-1)
        end

        it 'should return the deleted user record' do
          return_value = destroy
          return_value.should == @user
          return_value.should be_destroyed
        end

        it 'should log the action' do
          AdminLogger.any_instance.expects(:log_user_deletion).with(@user).once
          destroy
        end

        it 'should unregister the nickname as the discourse hub if hub integration is enabled' do
          SiteSetting.stubs(:call_discourse_hub?).returns(true)
          DiscourseHub.expects(:unregister_nickname).with(@user.username)
          destroy
        end

        it 'should not try to unregister the nickname as the discourse hub if hub integration is disabled' do
          SiteSetting.stubs(:call_discourse_hub?).returns(false)
          DiscourseHub.expects(:unregister_nickname).never
          destroy
        end
      end

      context 'and destroy fails' do
        before do
          @user.stubs(:destroy).returns(false)
        end

        it 'should return false' do
          destroy.should == false
        end

        it 'should not log the action' do
          AdminLogger.any_instance.expects(:log_user_deletion).never
          destroy
        end

        it 'should not unregister the user at the discourse hub' do
          DiscourseHub.expects(:unregister_nickname).never
          destroy rescue nil
        end
      end
    end
  end

end
