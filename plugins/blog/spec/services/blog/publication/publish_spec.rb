# frozen_string_literal: true

RSpec.describe Blog::Publication::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
    end

    let(:params) { { topic_id: topic.id } }

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it "publishes nothing and leaves no submission behind" do
        expect(result).to fail_a_policy(:can_publish_article)
        expect(Blog::Publication.where(topic:)).not_to exist
      end
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "without a revision" do
      it { is_expected.to run_successfully }

      it "submits, approves and publishes the current draft" do
        result
        published = publication.reload
        expect(published).to be_published
        expect(published.published_revision).to have_attributes(
          raw: first_post.raw,
          approver: acting_user,
        )
        expect(published.submitted_revision).to eq(published.published_revision)
        expect(
          UserHistory.where(custom_type: %w[blog_submit blog_approve blog_publish]).count,
        ).to eq(3)
      end
    end

    context "when the current draft cannot be submitted" do
      before do
        publication.update!(draft_topic: topic)
        topic.update!(archived: true)
      end

      it { is_expected.to fail_a_step(:submit_current_draft) }
    end

    context "with a revision" do
      let(:revision) { submit_blog_draft(publication, writer) }
      let(:params) { { topic_id: topic.id, revision_id: revision.id } }

      context "when the revision belongs to another article" do
        fab!(:other_topic) { Fabricate(:topic, category: drafts, user: writer) }

        let(:revision) do
          Fabricate(:post, topic: other_topic, user: writer)
          submit_blog_draft(Blog::Publication.for_topic(other_topic), writer)
        end

        it { is_expected.to fail_to_find_a_model(:revision) }
      end

      context "when the revision is not approved" do
        it "publishes nothing" do
          expect(result).to fail_a_policy(:revision_awaits_release)
          expect(publication.reload).not_to be_published
        end
      end

      context "when the revision is approved" do
        before { approve_blog_revision(publication, revision, acting_user) }

        it { is_expected.to run_successfully }

        it "publishes that revision into a new discussion" do
          result
          expect(publication.reload).to have_attributes(
            published?: true,
            published_revision: revision,
            publisher: acting_user,
            path: revision.data["path"],
          )
          expect(publication.discussion_topic).to have_attributes(
            category_id: category.id,
            title: revision.title,
          )
          expect(publication.paths.pluck(:path)).to contain_exactly(publication.path)
          expect(UserHistory.find_by(custom_type: "blog_publish")).to have_attributes(
            acting_user_id: acting_user.id,
            topic_id: publication.discussion_topic_id,
          )
        end

        it "cancels a pending schedule" do
          schedule_blog_revision(publication, revision, acting_user)

          expect { result }.to change { publication.reload.scheduled_at }.to(nil)
        end
      end

      context "when the working copy is gone" do
        fab!(:topic) { Fabricate(:topic, category:, user: writer) }
        fab!(:first_post) { Fabricate(:post, topic:, user: writer) }

        before do
          approve_blog_revision(publication, revision, acting_user)
          publication.draft_topic.trash!
        end

        it { is_expected.to fail_to_find_a_model(:working_copy) }
      end

      context "when the working copy is no longer publishable" do
        before do
          approve_blog_revision(publication, revision, acting_user)
          topic.update!(archived: true)
        end

        it { is_expected.to fail_a_policy(:releasable) }
      end

      context "when the working copy is a published page" do
        before do
          approve_blog_revision(publication, revision, acting_user)
          Fabricate(:published_page, topic:)
        end

        it { is_expected.to fail_a_policy(:not_published_as_page) }
      end

      context "when another article already uses the path" do
        fab!(:other_topic) { Fabricate(:topic, category:) }

        before do
          approve_blog_revision(publication, revision, acting_user)
          other = Blog::Publication.create!(topic: other_topic, path: "/elsewhere")
          other.paths.create!(path: revision.data["path"])
        end

        it { is_expected.to fail_with_an_invalid_model(:publication) }
      end

      context "when the discussion cannot be created" do
        before do
          approve_blog_revision(publication, revision, acting_user)
          SiteSetting.min_first_post_length = 100
        end

        it "rolls the release back" do
          expect { result }.not_to change { Topic.count }
          expect(result).to fail_with_exception(ActiveRecord::RecordNotSaved)
          expect(publication.reload).not_to be_published
        end
      end

      context "when another revision was submitted after scheduling this one" do
        before do
          approve_blog_revision(publication, revision, acting_user)
          schedule_blog_revision(publication, revision, acting_user)
          first_post.revise(writer, raw: "A newer draft for the next editorial round.")
          submit_blog_draft(publication, writer)
        end

        it "still releases the scheduled revision" do
          expect(result).to run_successfully
          expect(publication.reload.published_revision).to eq(revision)
        end
      end
    end

    context "with a live article whose discussion belongs to someone else" do
      fab!(:publishers, :group)
      fab!(:acting_user) { Fabricate(:user, groups: [publishers], refresh_auto_groups: true) }

      before do
        SiteSetting.blog_publisher_groups = publishers.id.to_s
        drafts.set_permissions(:staff => :full, writers.name => :full, publishers.name => :full)
        drafts.save!
        publish_blog_draft(publication, Fabricate(:admin))
        first_post.revise(writer, raw: "A correction to the live article, ready to go out.")
        topic.update!(title: "A corrected title for the live article")
      end

      it "republishes the correction into the existing discussion" do
        discussion = publication.discussion_topic

        expect(result).to run_successfully
        expect(discussion.reload).to have_attributes(
          id: publication.reload.discussion_topic_id,
          title: "A corrected title for the live article",
        )
        expect(discussion.first_post.raw).to eq(first_post.reload.raw)
        expect(discussion.user).not_to eq(acting_user)
      end
    end
  end
end
