# frozen_string_literal: true

RSpec.describe Blog::Publication::RunSchedule do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:publication_id) }
    it { is_expected.to validate_presence_of(:token) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
    end

    let(:revision) { submit_blog_draft(publication, writer) }
    let(:token) { publication.schedule_token }
    let(:params) { { publication_id: publication.id, token: } }

    before do
      freeze_time
      approve_blog_revision(publication, revision, acting_user)
      schedule_blog_revision(publication, revision, acting_user)
      freeze_time 3.hours.from_now
    end

    context "when contract is invalid" do
      let(:params) { { publication_id: publication.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the publication does not exist" do
      let(:params) { { publication_id: 0, token: } }

      it { is_expected.to fail_to_find_a_model(:publication) }
    end

    context "when the schedule was replaced" do
      let(:token) { SecureRandom.uuid }

      it "publishes nothing" do
        expect(result).to fail_a_policy(:schedule_due)
        expect(publication.reload).not_to be_published
      end
    end

    context "when the schedule is not due yet" do
      before { freeze_time 2.hours.ago }

      it { is_expected.to fail_a_policy(:schedule_due) }
    end

    context "when the scheduler can no longer publish" do
      before { acting_user.update!(suspended_till: 1.day.from_now) }

      it { is_expected.to run_successfully }

      it "records why the schedule stopped" do
        result
        expect(publication.reload).to have_attributes(
          published?: false,
          scheduled_at: nil,
          schedule_token: nil,
          schedule_error: I18n.t("blog.editorial.access_lost"),
        )
      end
    end

    context "when the path was taken in the meantime" do
      fab!(:other_topic) { Fabricate(:topic, category:) }

      before do
        other = Blog::Publication.create!(topic: other_topic, path: "/elsewhere")
        other.paths.create!(path: revision.data["path"])
      end

      it "records the error and creates no discussion" do
        expect { result }.not_to change { Topic.count }
        expect(publication.reload).to have_attributes(published?: false, scheduled_at: nil)
        expect(publication.schedule_error).to include(I18n.t("blog.errors.path_taken"))
      end
    end

    context "when the discussion cannot be created" do
      before { SiteSetting.min_first_post_length = 100 }

      it "rolls back the release and records the error" do
        expect { result }.not_to change { Topic.count }
        expect(publication.reload).to have_attributes(published?: false, scheduled_at: nil)
        expect(publication.schedule_error).to be_present
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "publishes the scheduled revision as the scheduler" do
        result
        expect(publication.reload).to have_attributes(
          published?: true,
          published_revision: revision,
          publisher: acting_user,
          scheduled_at: nil,
          schedule_error: "",
        )
      end
    end

    context "with a dated path format scheduled into the next month" do
      let(:publication) do
        SiteSetting.blog_path_format = "/{year}/{month}/{slug}"
        freeze_time Time.utc(2026, 10, 31, 22)
        Blog::Publication.for_topic(topic)
      end

      it "publishes under the month of the release" do
        expect(revision.data["path"]).to eq("/2026/10/#{topic.slug}")

        result
        expect(publication.reload.path).to eq("/2026/11/#{topic.slug}")
      end
    end
  end
end
