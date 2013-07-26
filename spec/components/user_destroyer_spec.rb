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

    it 'returns an instance of UserDestroyer when user is a moderator' do
      UserDestroyer.new( Fabricate(:moderator) ).should be_a(UserDestroyer)
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

    it 'raises an error when user is nil' do
      expect { UserDestroyer.new(@admin).destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { UserDestroyer.new(@admin).destroy('nothing') }.to raise_error(Discourse::InvalidParameters)
    end

    shared_examples "successfully destroy a user" do
      it 'should delete the user' do
        expect { destroy }.to change { User.count }.by(-1)
      end

      it 'should return the deleted user record' do
        return_value = destroy
        return_value.should == @user
        return_value.should be_destroyed
      end

      it 'should log the action' do
        StaffActionLogger.any_instance.expects(:log_user_deletion).with(@user, anything).once
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

    shared_examples "email block list" do
      it "doesn't add email to block list by default" do
        BlockedEmail.expects(:block).never
        destroy
      end

      it "adds email to block list if block_email is true" do
        b = Fabricate.build(:blocked_email, email: @user.email)
        BlockedEmail.expects(:block).with(@user.email).returns(b)
        b.expects(:record_match!).once.returns(true)
        UserDestroyer.new(@admin).destroy(@user, destroy_opts.merge({block_email: true}))
      end
    end

    context 'user has posts' do
      let!(:post) { Fabricate(:post, user: @user) }

      context "delete_posts is false" do
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }

        it 'should not delete the user' do
          expect { destroy rescue nil }.to_not change { User.count }
        end

        it 'should raise an error' do
          expect { destroy }.to raise_error( UserDestroyer::PostsExistError )
        end

        it 'should not log the action' do
          StaffActionLogger.any_instance.expects(:log_user_deletion).never
          destroy rescue nil
        end

        it 'should not unregister the user at the discourse hub' do
          DiscourseHub.expects(:unregister_nickname).never
          destroy rescue nil
        end
      end

      context "delete_posts is true" do
        let(:destroy_opts) { {delete_posts: true} }
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user, destroy_opts) }

        include_examples "successfully destroy a user"
        include_examples "email block list"

        it "deletes the posts" do
          destroy
          post.reload.deleted_at.should_not be_nil
          post.nuked_user.should be_true
        end
      end
    end

    context 'user has no posts' do
      context 'and destroy succeeds' do

        let(:destroy_opts) { {} }
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }

        include_examples "successfully destroy a user"
        include_examples "email block list"

        it "should mark the user's deleted posts as belonging to a nuked user" do
          post = Fabricate(:post, user: @user, deleted_at: 1.hour.ago)
          expect { destroy }.to change { User.count }.by(-1)
          post.reload.nuked_user.should be_true
        end
      end

      context 'and destroy fails' do
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }

        before do
          @user.stubs(:destroy).returns(false)
        end

        it 'should return false' do
          destroy.should == false
        end

        it 'should not log the action' do
          StaffActionLogger.any_instance.expects(:log_user_deletion).never
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
