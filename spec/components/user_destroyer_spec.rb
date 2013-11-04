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
        ScreenedEmail.expects(:block).never
        destroy
      end

      it "adds email to block list if block_email is true" do
        b = Fabricate.build(:screened_email, email: @user.email)
        ScreenedEmail.expects(:block).with(@user.email, has_key(:ip_address)).returns(b)
        b.expects(:record_match!).once.returns(true)
        UserDestroyer.new(@admin).destroy(@user, destroy_opts.merge({block_email: true}))
      end
    end

    context 'user has posts' do
      let!(:topic_starter) { Fabricate(:user) }
      let!(:topic) { Fabricate(:topic, user: topic_starter) }
      let!(:first_post) { Fabricate(:post, user: topic_starter, topic: topic) }
      let!(:post) { Fabricate(:post, user: @user, topic: topic) }

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
          post.user_id.should be_nil
        end

        it "does not delete topics started by others in which the user has replies" do
          destroy
          topic.reload.deleted_at.should be_nil
          topic.user_id.should_not be_nil
        end

        it "deletes topics started by the deleted user" do
          spammer_topic = Fabricate(:topic, user: @user)
          spammer_post = Fabricate(:post, user: @user, topic: spammer_topic)
          destroy
          spammer_topic.reload.deleted_at.should_not be_nil
          spammer_topic.user_id.should be_nil
        end
      end
    end

    context 'user has deleted posts' do
      let!(:deleted_post) { Fabricate(:post, user: @user, deleted_at: 1.hour.ago) }
      it "should mark the user's deleted posts as belonging to a nuked user" do
        expect { UserDestroyer.new(@admin).destroy(@user) }.to change { User.count }.by(-1)
        deleted_post.reload.user_id.should be_nil
      end
    end

    context 'user has no posts' do
      context 'and destroy succeeds' do
        let(:destroy_opts) { {} }
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }

        include_examples "successfully destroy a user"
        include_examples "email block list"
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

    context 'user has posts with links' do
      context 'external links' do
        before do
          @post = Fabricate(:post_with_external_links, user: @user)
          TopicLink.extract_from(@post)
        end

        it "doesn't add ScreenedUrl records by default" do
          ScreenedUrl.expects(:watch).never
          UserDestroyer.new(@admin).destroy(@user, {delete_posts: true})
        end

        it "adds ScreenedUrl records when :block_urls is true" do
          ScreenedUrl.expects(:watch).with(anything, anything, has_key(:ip_address)).at_least_once
          UserDestroyer.new(@admin).destroy(@user, {delete_posts: true, block_urls: true})
        end
      end

      context 'internal links' do
        before do
          @post = Fabricate(:post_with_external_links, user: @user)
          TopicLink.extract_from(@post)
          TopicLink.any_instance.stubs(:internal).returns(true)
        end

        it "doesn't add ScreenedUrl records" do
          ScreenedUrl.expects(:watch).never
          UserDestroyer.new(@admin).destroy(@user, {delete_posts: true, block_urls: true})
        end
      end

      context 'with oneboxed links' do
        before do
          @post = Fabricate(:post_with_youtube, user: @user)
          TopicLink.extract_from(@post)
        end

        it "doesn't add ScreenedUrl records" do
          ScreenedUrl.expects(:watch).never
          UserDestroyer.new(@admin).destroy(@user, {delete_posts: true, block_urls: true})
        end
      end
    end

    context 'ip address screening' do
      it "doesn't create screened_ip_address records by default" do
        ScreenedIpAddress.expects(:watch).never
        UserDestroyer.new(@admin).destroy(@user)
      end

      it "creates new screened_ip_address records when block_ip is true" do
        ScreenedIpAddress.expects(:watch).with(@user.ip_address).returns(stub_everything)
        UserDestroyer.new(@admin).destroy(@user, {block_ip: true})
      end
    end

    context 'user created a category' do
      let!(:category) { Fabricate(:category, user: @user) }

      it "assigns the system user to the categories" do
        UserDestroyer.new(@admin).destroy(@user, {delete_posts: true})
        category.reload.user_id.should == Discourse.system_user.id
        category.topic.should be_present
        category.topic.user_id.should == Discourse.system_user.id
      end
    end
  end

end
