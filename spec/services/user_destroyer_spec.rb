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

    it 'raises an error when regular user tries to delete another user' do
      expect { UserDestroyer.new(@user).destroy(Fabricate(:user)) }.to raise_error(Discourse::InvalidAccess)
    end

    shared_examples "successfully destroy a user" do
      it 'should delete the user' do
        expect { destroy }.to change { User.count }.by(-1)
      end

      it 'should return the deleted user record' do
        return_value = destroy
        expect(return_value).to eq(@user)
        expect(return_value).to be_destroyed
      end

      it 'should log the action' do
        StaffActionLogger.any_instance.expects(:log_user_deletion).with(@user, anything).once
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

    context 'user deletes self' do
      let(:destroy_opts) { {delete_posts: true} }
      subject(:destroy) { UserDestroyer.new(@user).destroy(@user, destroy_opts) }

      include_examples "successfully destroy a user"
    end

    context "with a queued post" do
      let(:user) { Fabricate(:user) }
      let(:admin) { Fabricate(:admin) }
      let!(:qp) { Fabricate(:queued_post, user: user) }

      it "removes the queued post" do
        UserDestroyer.new(admin).destroy(user)
        expect(QueuedPost.where(user_id: user.id).count).to eq(0)
      end

    end

    context "with a draft" do
      let(:user) { Fabricate(:user) }
      let(:admin) { Fabricate(:admin) }
      let!(:draft) { Draft.set(user, 'test', 1, 'test') }

      it "removed the draft" do
        UserDestroyer.new(admin).destroy(user)
        expect(Draft.where(user_id: user.id).count).to eq(0)
      end
    end

    context 'user has posts' do
      let!(:topic_starter) { Fabricate(:user) }
      let!(:topic) { Fabricate(:topic, user: topic_starter) }
      let!(:first_post) { Fabricate(:post, user: topic_starter, topic: topic) }
      let!(:post) { Fabricate(:post, user: @user, topic: topic) }

      context "delete_posts is false" do
        subject(:destroy) { UserDestroyer.new(@admin).destroy(@user) }
        before do
          @user.stubs(:post_count).returns(1)
          @user.stubs(:first_post_created_at).returns(Time.zone.now)
        end

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
      end

      context "delete_posts is true" do
        let(:destroy_opts) { {delete_posts: true} }

        context "staff deletes user" do
          subject(:destroy) { UserDestroyer.new(@admin).destroy(@user, destroy_opts) }

          include_examples "successfully destroy a user"
          include_examples "email block list"

          it "deletes the posts" do
            destroy
            expect(post.reload.deleted_at).not_to eq(nil)
            expect(post.user_id).to eq(nil)
          end

          it "does not delete topics started by others in which the user has replies" do
            destroy
            expect(topic.reload.deleted_at).to eq(nil)
            expect(topic.user_id).not_to eq(nil)
          end

          it "deletes topics started by the deleted user" do
            spammer_topic = Fabricate(:topic, user: @user)
            spammer_post = Fabricate(:post, user: @user, topic: spammer_topic)
            destroy
            expect(spammer_topic.reload.deleted_at).not_to eq(nil)
            expect(spammer_topic.user_id).to eq(nil)
          end

          context "delete_as_spammer is true" do

            before { destroy_opts[:delete_as_spammer] = true }

            it "agrees with flags on user's posts" do
              spammer_post = Fabricate(:post, user: @user)
              flag = PostAction.act(@admin, spammer_post, PostActionType.types[:inappropriate])
              expect(flag.agreed_at).to eq(nil)

              destroy

              flag.reload
              expect(flag.agreed_at).not_to eq(nil)
            end

          end
        end

        context "users deletes self" do
          subject(:destroy) { UserDestroyer.new(@user).destroy(@user, destroy_opts) }

          include_examples "successfully destroy a user"
          include_examples "email block list"

          it "deletes the posts" do
            destroy
            expect(post.reload.deleted_at).not_to eq(nil)
            expect(post.user_id).to eq(nil)
          end
        end
      end
    end

    context 'user has no posts, but user_stats table has post_count > 0' do
      before do
        # out of sync user_stat data shouldn't break UserDestroyer
        @user.user_stat.update_attribute(:post_count, 1)
      end
      subject(:destroy) { UserDestroyer.new(@user).destroy(@user, {delete_posts: false}) }

      include_examples "successfully destroy a user"
    end

    context 'user has deleted posts' do
      let!(:deleted_post) { Fabricate(:post, user: @user, deleted_at: 1.hour.ago) }
      it "should mark the user's deleted posts as belonging to a nuked user" do
        expect { UserDestroyer.new(@admin).destroy(@user) }.to change { User.count }.by(-1)
        expect(deleted_post.reload.user_id).to eq(nil)
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
          expect(destroy).to eq(false)
        end

        it 'should not log the action' do
          StaffActionLogger.any_instance.expects(:log_user_deletion).never
          destroy
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

      context "block_ip is true" do
        it "creates a new screened_ip_address record" do
          ScreenedIpAddress.expects(:watch).with(@user.ip_address).returns(stub_everything)
          UserDestroyer.new(@admin).destroy(@user, {block_ip: true})
        end

        it "creates two new screened_ip_address records when registration_ip_address is different than last ip_address" do
          @user.registration_ip_address = '12.12.12.12'
          ScreenedIpAddress.expects(:watch).with(@user.ip_address).returns(stub_everything)
          ScreenedIpAddress.expects(:watch).with(@user.registration_ip_address).returns(stub_everything)
          UserDestroyer.new(@admin).destroy(@user, {block_ip: true})
        end
      end
    end

    context 'user created a category' do
      let!(:category) { Fabricate(:category, user: @user) }

      it "assigns the system user to the categories" do
        UserDestroyer.new(@admin).destroy(@user, {delete_posts: true})
        expect(category.reload.user_id).to eq(Discourse.system_user.id)
        expect(category.topic).to be_present
        expect(category.topic.user_id).to eq(Discourse.system_user.id)
      end
    end

    context 'user got an email' do
      let(:user) { Fabricate(:user) }
      let!(:email_log) { Fabricate(:email_log, user: user) }

      it "deletes the email log" do
        expect {
          UserDestroyer.new(@admin).destroy(user, {delete_posts: true})
        }.to change { EmailLog.count }.by(-1)
      end
    end

    context 'user liked things' do
      before do
        @topic = Fabricate(:topic, user: Fabricate(:user))
        @post = Fabricate(:post, user: @topic.user, topic: @topic)
        @like = PostAction.act(@user, @post, PostActionType.types[:like])
      end

      it 'should destroy the like' do
        expect {
          UserDestroyer.new(@admin).destroy(@user, {delete_posts: true})
        }.to change { PostAction.count }.by(-1)
        expect(@post.reload.like_count).to eq(0)
      end
    end
  end

end
