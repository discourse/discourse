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
      it "doesn't change version" do
        lambda {
          subject.revise!(post.user, { raw: post.raw }).should == false
          post.reload
        }.should_not change(post, :version)
      end
    end

    describe 'ninja editing' do
      it 'correctly applies edits' do
        SiteSetting.ninja_edit_window = 1.minute.to_i
        subject.revise!(post.user, { raw: 'updated body' }, revised_at: post.updated_at + 10.seconds)
        post.reload

        post.version.should == 1
        post.public_version.should == 1
        post.revisions.size.should == 0
        post.last_version_at.should == first_version_at
        subject.category_changed.should be_blank
      end
    end

    describe 'revision much later' do

      let!(:revised_at) { post.updated_at + 2.minutes }

      before do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
        subject.revise!(post.user, { raw: 'updated body' }, revised_at: revised_at)
        post.reload
      end

      it "doesn't update a category" do
        subject.category_changed.should be_blank
      end

      it 'updates the versions' do
        post.version.should == 2
        post.public_version.should == 2
      end

      it 'creates a new revision' do
        post.revisions.size.should == 1
      end

      it "updates the last_version_at" do
        post.last_version_at.to_i.should == revised_at.to_i
      end

      describe "new edit window" do

        before do
          subject.revise!(post.user, { raw: 'yet another updated body' }, revised_at: revised_at)
          post.reload
        end

        it "doesn't create a new version if you do another" do
          post.version.should == 2
          post.public_version.should == 2
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
            subject.revise!(post.user, { raw: 'yet another, another updated body' }, revised_at: new_revised_at)
            post.reload
          end

          it "does create a new version after the edit window" do
            post.version.should == 3
            post.public_version.should == 3
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

      it "should have no description by default" do
        category.description.should be_blank
      end

      context "one paragraph description" do
        before do
          subject.revise!(post.user, { raw: new_description })
          category.reload
        end

        it "returns the changed category info" do
          subject.category_changed.should == category
        end

        it "updates the description of the category" do
          category.description.should == new_description
        end
      end

      context "multiple paragraph description" do
        before do
          subject.revise!(post.user, { raw: "#{new_description}\n\nOther content goes here." })
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
          subject.revise!(post.user, { raw: Category.post_template })
          category.reload
        end

        it "puts the description back to nothing" do
          category.description.should be_blank
        end

        it "returns the changed category info" do
          subject.category_changed.should == category
        end
      end

    end

    describe 'rate limiter' do
      let(:changed_by) { Fabricate(:coding_horror) }

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        subject.revise!(changed_by, { raw: 'updated body' })
      end
    end

    describe "admin editing a new user's post" do
      let(:changed_by) { Fabricate(:admin) }

      before do
        SiteSetting.stubs(:newuser_max_images).returns(0)
        url = "http://i.imgur.com/wfn7rgU.jpg"
        Oneboxer.stubs(:onebox).with(url, anything).returns("<img src='#{url}'>")
        subject.revise!(changed_by, { raw: "So, post them here!\n#{url}" })
      end

      it "allows an admin to insert images into a new user's post" do
        post.errors.should be_blank
      end

      it "marks the admin as the last updater" do
        post.last_editor_id.should == changed_by.id
      end

    end

    describe "new user editing their own post" do
      before do
        SiteSetting.stubs(:newuser_max_images).returns(0)
        url = "http://i.imgur.com/FGg7Vzu.gif"
        Oneboxer.stubs(:cached_onebox).with(url, anything).returns("<img src='#{url}'>")
        subject.revise!(post.user, { raw: "So, post them here!\n#{url}" })
      end

      it "doesn't allow images to be inserted" do
        post.errors.should be_present
      end

    end


    describe 'with a new body' do
      let(:changed_by) { Fabricate(:coding_horror) }
      let!(:result) { subject.revise!(changed_by, { raw: "lets update the body" }) }

      it 'returns true' do
        result.should == true
      end

      it 'updates the body' do
        post.raw.should == "lets update the body"
      end

      it 'sets the invalidate oneboxes attribute' do
        post.invalidate_oneboxes.should == true
      end

      it 'increased the versions' do
        post.version.should == 2
        post.public_version.should == 2
      end

      it 'has the new revision' do
        post.revisions.size.should == 1
      end

      it "saved the user who made the change in the revisions" do
        post.revisions.first.user_id.should == changed_by.id
      end

      it "updates the word count" do
        post.word_count.should == 4
        post.topic.reload
        post.topic.word_count.should == 4
      end

      context 'second poster posts again quickly' do
        before do
          SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
          subject.revise!(changed_by, { raw: 'yet another updated body' }, revised_at: post.updated_at + 10.seconds)
          post.reload
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          post.version.should == 2
          post.public_version.should == 2
          post.revisions.size.should == 1
        end
      end
    end

    describe "topic excerpt" do
      it "topic excerpt is updated only if first post is revised" do
        revisor = described_class.new(post)
        first_post = topic.posts.by_post_number.first
        expect {
          revisor.revise!(first_post.user, { raw: 'Edit the first post' }, revised_at: first_post.updated_at + 10.seconds)
          topic.reload
        }.to change { topic.excerpt }
        second_post = Fabricate(:post, post_args.merge(post_number: 2, topic_id: topic.id))
        expect {
          described_class.new(second_post).revise!(second_post.user, { raw: 'Edit the 2nd post' })
          topic.reload
        }.to_not change { topic.excerpt }
      end
    end

    it "doesn't strip starting whitespaces" do
      subject.revise!(post.user, { raw: "    <-- whitespaces -->    " })
      post.reload
      post.raw.should == "    <-- whitespaces -->"
    end

  end
end
