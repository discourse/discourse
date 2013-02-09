require 'spec_helper'
require 'post_revisor'

describe PostRevisor do

  let(:topic) { Fabricate(:topic) }
  let(:post_args) { {user: topic.user, topic: topic} }

  context 'revise' do

    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    subject { described_class.new(post) }

    describe 'with the same body' do

      it 'returns false' do
        subject.revise!(post.user, post.raw).should be_false
      end

      it "doesn't change cached_version" do
        lambda { subject.revise!(post.user, post.raw); post.reload }.should_not change(post, :cached_version)
      end

    end

    describe 'ninja editing' do
      before do
        SiteSetting.expects(:ninja_edit_window).returns(1.minute.to_i)
        subject.revise!(post.user, 'updated body', revised_at: post.updated_at + 10.seconds)
        post.reload
      end

      it 'does not update cached_version' do
        post.cached_version.should == 1
      end

      it 'does not create a new version' do
        post.all_versions.size.should == 1
      end

      it "doesn't change the last_version_at" do
        post.last_version_at.should == first_version_at
      end
    end

    describe 'revision much later' do

      let!(:revised_at) { post.updated_at + 2.minutes }

      before do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
        subject.revise!(post.user, 'updated body', revised_at: revised_at)
        post.reload
      end

      it 'updates the cached_version' do
        post.cached_version.should == 2
      end

      it 'creates a new version' do
        post.all_versions.size.should == 2
      end

      it "updates the last_version_at" do
        post.last_version_at.to_i.should == revised_at.to_i
      end

      describe "new edit window" do

        before do
          subject.revise!(post.user, 'yet another updated body', revised_at: revised_at)
          post.reload
        end

        it "doesn't create a new version if you do another" do
          post.cached_version.should == 2
        end

        it "doesn't change last_version_at" do
          post.last_version_at.to_i.should == revised_at.to_i
        end

        context "after second window" do

          let!(:new_revised_at) {revised_at + 2.minutes}

          before do
            subject.revise!(post.user, 'yet another, another updated body', revised_at: new_revised_at)
            post.reload
          end

          it "does create a new version after the edit window" do
            post.cached_version.should == 3
          end

          it "does create a new version after the edit window" do
            post.last_version_at.to_i.should == new_revised_at.to_i
          end
        end
      end
    end

    describe 'rate limiter' do
      let(:changed_by) { Fabricate(:coding_horror) }

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        subject.revise!(changed_by, 'updated body')
      end
    end

    describe 'with a new body' do
      let(:changed_by) { Fabricate(:coding_horror) }
      let!(:result) { subject.revise!(changed_by, 'updated body') }

      it 'returns true' do
        result.should be_true
      end

      it 'updates the body' do
        post.raw.should == 'updated body'
      end

      it 'sets the invalidate oneboxes attribute' do
        post.invalidate_oneboxes.should == true
      end

      it 'increased the cached_version' do
        post.cached_version.should == 2
      end

      it 'has the new version in all_versions' do
        post.all_versions.size.should == 2
      end

      it 'has versions' do
        post.versions.should be_present
      end

      it "saved the user who made the change in the version" do
        post.versions.first.user.should be_present
      end

      context 'second poster posts again quickly' do
        before do
          SiteSetting.expects(:ninja_edit_window).returns(1.minute.to_i)
          subject.revise!(changed_by, 'yet another updated body', revised_at: post.updated_at + 10.seconds)
          post.reload
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          post.cached_version.should == 2
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          post.all_versions.size.should == 2
        end
      end
    end
  end
end
