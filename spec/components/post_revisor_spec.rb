require 'spec_helper'
require 'post_revisor'

describe PostRevisor do

  let(:topic) { Fabricate(:topic) }
  let(:newuser) { Fabricate(:newuser) }
  let(:post_args) { {user: newuser, topic: topic} }

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

      it "doesn't update a category" do
        subject.category_changed.should be_blank
      end

    end

    describe 'revision much later' do

      let!(:revised_at) { post.updated_at + 2.minutes }

      before do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
        subject.revise!(post.user, 'updated body', revised_at: revised_at)
        post.reload
      end

      it "doesn't update a category" do
        subject.category_changed.should be_blank
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

        it "doesn't update a category" do
          subject.category_changed.should be_blank
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

    describe 'category topic' do

      let!(:category) do
        category = Fabricate(:category)
        category.update_column(:topic_id, topic.id)
        category
      end

      let(:new_description) { "this is my new description." }

      it "should have to description by default" do
        category.description.should be_blank
      end

      context "one paragraph description" do
        before do
          subject.revise!(post.user, new_description)
          category.reload
        end

        it "returns true for category_changed" do
          subject.category_changed.should be_true
        end

        it "updates the description of the category" do
          category.description.should == new_description
        end
      end

      context "multiple paragraph description" do
        before do
          subject.revise!(post.user, "#{new_description}\n\nOther content goes here.")
          category.reload
        end

        it "returns the changed category info" do
          subject.category_changed.should == category
        end

        it "updates the description of the category" do
          category.description.should == new_description
        end
      end

      context 'when updating back to the original paragraph' do
        before do
          category.update_column(:description, 'this is my description')
          subject.revise!(post.user, Category.post_template)
          category.reload
        end

        it "puts the description back to nothing" do
          category.description.should be_blank
        end

        it "returns true for category_changed" do
          subject.category_changed.should == category
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

    describe "admin editing a new user's post" do
      let(:changed_by) { Fabricate(:admin) }

      before do
        SiteSetting.stubs(:newuser_max_images).returns(0)
        subject.revise!(changed_by, "So, post them here!\nhttp://i.imgur.com/FGg7Vzu.gif")
      end

      it "allows an admin to insert images into a new user's post" do
        post.errors.should be_blank
      end
    end

    describe "new user editing their own post" do
      before do
        SiteSetting.stubs(:newuser_max_images).returns(0)
        url = "http://i.imgur.com/FGg7Vzu.gif"
        # this test is problamatic, it leaves state in the onebox cache
        Oneboxer.invalidate(url)
        subject.revise!(post.user, "So, post them here!\n#{url}")
      end

      it "allows an admin to insert images into a new user's post" do
        post.errors.should be_present
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
