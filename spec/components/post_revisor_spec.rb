require 'spec_helper'
require 'post_revisor'

describe PostRevisor do

  let(:topic) { Fabricate(:topic) }
  let(:newuser) { Fabricate(:newuser) }
  let(:post_args) { { user: newuser, topic: topic } }

  context 'TopicChanges' do
    let(:topic) { Fabricate(:topic) }
    let(:tc) {
      topic.reload
      PostRevisor::TopicChanges.new(topic, topic.user)
    }

    it 'provides a guardian' do
      expect(tc.guardian).to be_an_instance_of Guardian
    end

    it 'tracks changes properly' do
      expect(tc.diff).to eq({})

      # it remembers changes we tell it to
      tc.record_change('height', '180cm', '170cm')
      expect(tc.diff['height']).to eq(['180cm', '170cm'])

      # it works with arrays of values
      tc.record_change('colors', nil, ['red', 'blue'])
      expect(tc.diff['colors']).to eq([nil, ['red', 'blue']])

      # it does not record changes to the same val
      tc.record_change('wat', 'js', 'js')
      expect(tc.diff['wat']).to be_nil

      tc.record_change('tags', ['a', 'b'], ['a', 'b'])
      expect(tc.diff['tags']).to be_nil

    end
  end

  context 'revise wiki' do

    before do
      # There used to be a bug where wiki changes were considered posting "too similar"
      # so this is enabled and checked
      $redis.delete_prefixed('unique-post')
      SiteSetting.unique_posts_mins = 10
    end

    it 'allows the user to change it to a wiki' do
      pc = PostCreator.new(newuser, topic_id: topic.id, raw: 'this is a post that will become a wiki')
      post = pc.create
      expect(post.revise(post.user, wiki: true)).to be_truthy
      post.reload
      expect(post.wiki).to be_truthy
    end
  end

  context 'revise' do
    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    subject { described_class.new(post) }

    describe 'with the same body' do
      it "doesn't change version" do
        expect {
          expect(subject.revise!(post.user, { raw: post.raw })).to eq(false)
          post.reload
        }.not_to change(post, :version)
      end
    end

    describe 'ninja editing' do
      it 'correctly applies edits' do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute)

        subject.revise!(post.user, { raw: 'updated body' }, revised_at: post.updated_at + 10.seconds)
        post.reload

        expect(post.version).to eq(1)
        expect(post.public_version).to eq(1)
        expect(post.revisions.size).to eq(0)
        expect(post.last_version_at).to eq(first_version_at)
        expect(subject.category_changed).to be_blank
      end

      it "doesn't create a new version" do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute)

        # making a revision
        subject.revise!(post.user, { raw: 'updated body' }, revised_at: post.updated_at + SiteSetting.ninja_edit_window + 1.seconds)
        # "roll back"
        subject.revise!(post.user, { raw: 'Hello world' }, revised_at: post.updated_at + SiteSetting.ninja_edit_window + 2.seconds)

        post.reload

        expect(post.version).to eq(1)
        expect(post.public_version).to eq(1)
        expect(post.revisions.size).to eq(0)
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
        expect(subject.category_changed).to be_blank
      end

      it 'updates the versions' do
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
      end

      it 'creates a new revision' do
        expect(post.revisions.size).to eq(1)
      end

      it "updates the last_version_at" do
        expect(post.last_version_at.to_i).to eq(revised_at.to_i)
      end

      describe "new edit window" do

        before do
          subject.revise!(post.user, { raw: 'yet another updated body' }, revised_at: revised_at)
          post.reload
        end

        it "doesn't create a new version if you do another" do
          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
        end

        it "doesn't change last_version_at" do
          expect(post.last_version_at.to_i).to eq(revised_at.to_i)
        end

        it "doesn't update a category" do
          expect(subject.category_changed).to be_blank
        end

        context "after second window" do

          let!(:new_revised_at) {revised_at + 2.minutes}

          before do
            subject.revise!(post.user, { raw: 'yet another, another updated body' }, revised_at: new_revised_at)
            post.reload
          end

          it "does create a new version after the edit window" do
            expect(post.version).to eq(3)
            expect(post.public_version).to eq(3)
          end

          it "does create a new version after the edit window" do
            expect(post.last_version_at.to_i).to eq(new_revised_at.to_i)
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
        expect(category.description).to be_blank
      end

      context "one paragraph description" do
        before do
          subject.revise!(post.user, { raw: new_description })
          category.reload
        end

        it "returns the changed category info" do
          expect(subject.category_changed).to eq(category)
        end

        it "updates the description of the category" do
          expect(category.description).to eq(new_description)
        end
      end

      context "multiple paragraph description" do
        before do
          subject.revise!(post.user, { raw: "#{new_description}\n\nOther content goes here." })
          category.reload
        end

        it "returns the changed category info" do
          expect(subject.category_changed).to eq(category)
        end

        it "updates the description of the category" do
          expect(category.description).to eq(new_description)
        end
      end

      context 'when updating back to the original paragraph' do
        before do
          category.update_column(:description, 'this is my description')
          subject.revise!(post.user, { raw: Category.post_template })
          category.reload
        end

        it "puts the description back to nothing" do
          expect(category.description).to be_blank
        end

        it "returns the changed category info" do
          expect(subject.category_changed).to eq(category)
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
        expect(post.errors).to be_blank
      end

      it "marks the admin as the last updater" do
        expect(post.last_editor_id).to eq(changed_by.id)
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
        expect(post.errors).to be_present
      end

    end


    describe 'with a new body' do
      let(:changed_by) { Fabricate(:coding_horror) }
      let!(:result) { subject.revise!(changed_by, { raw: "lets update the body" }) }

      it 'returns true' do
        expect(result).to eq(true)
      end

      it 'updates the body' do
        expect(post.raw).to eq("lets update the body")
      end

      it 'sets the invalidate oneboxes attribute' do
        expect(post.invalidate_oneboxes).to eq(true)
      end

      it 'increased the versions' do
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
      end

      it 'has the new revision' do
        expect(post.revisions.size).to eq(1)
      end

      it "saved the user who made the change in the revisions" do
        expect(post.revisions.first.user_id).to eq(changed_by.id)
      end

      it "updates the word count" do
        expect(post.word_count).to eq(4)
        post.topic.reload
        expect(post.topic.word_count).to eq(4)
      end

      context 'second poster posts again quickly' do
        before do
          SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
          subject.revise!(changed_by, { raw: 'yet another updated body' }, revised_at: post.updated_at + 10.seconds)
          post.reload
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
          expect(post.revisions.size).to eq(1)
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
      expect(post.raw).to eq("    <-- whitespaces -->")
    end

  end
end
