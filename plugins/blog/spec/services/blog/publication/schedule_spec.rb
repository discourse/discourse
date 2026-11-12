# frozen_string_literal: true

RSpec.describe Blog::Publication::Schedule do
  describe described_class::Contract, type: :model do
    before { freeze_time }

    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:revision_id) }

    it "only accepts publication times between a minute and a year ahead" do
      times = [nil, "invalid", 1.minute.from_now, 2.minutes.from_now, 1.year.from_now]
      accepted =
        (times + [1.year.from_now + 1]).select do |time|
          described_class.new(scheduled_at: time).tap(&:validate).errors[:base].empty?
        end

      expect(accepted).to eq([2.minutes.from_now, 1.year.from_now])
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    include_context "with blog editorial setup"

    fab!(:topic) { Fabricate(:topic, category: drafts, user: writer) }
    fab!(:first_post) do
      Fabricate(:post, topic:, user: writer, raw: "An article ready for a careful review.")
    end

    fab!(:publisher, :admin)

    let(:revision) { submit_blog_draft(publication, writer) }
    let(:revision_id) { revision.id }
    let(:scheduled_at) { 2.hours.from_now }
    let(:params) { { topic_id: topic.id, revision_id:, scheduled_at: } }

    before do
      freeze_time
      approve_blog_revision(publication, revision, publisher)
    end

    context "when contract is invalid" do
      let(:scheduled_at) { 1.minute.ago }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0, revision_id:, scheduled_at: } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the topic is not an article yet" do
      fab!(:untracked) { Fabricate(:topic, category: drafts, user: writer) }

      let(:params) { { topic_id: untracked.id, revision_id:, scheduled_at: } }

      it "leaves no publication behind" do
        expect(result).to fail_to_find_a_model(:publication)
        expect(Blog::Publication.where(topic: untracked)).not_to exist
      end
    end

    context "when the user is not a publisher" do
      fab!(:acting_user) { writer }

      it { is_expected.to fail_a_policy(:can_publish_article) }
    end

    context "when the blog is not ready" do
      before { SiteSetting.prevent_anons_from_downloading_files = true }

      it { is_expected.to fail_a_policy(:blog_ready) }
    end

    context "when the revision does not exist" do
      let(:revision_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:revision) }
    end

    context "when the revision is no longer the approved one" do
      before do
        first_post.revise(writer, raw: "A newer draft that has not been approved yet.")
        submit_blog_draft(publication, writer)
      end

      it { is_expected.to fail_a_policy(:revision_is_approved) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "schedules the revision for release" do
        result
        expect(publication.reload).to have_attributes(
          scheduled_revision: revision,
          scheduler: acting_user,
          schedule_token: be_present,
          schedule_error: "",
        )
        expect(publication.scheduled_at).to eq_time(scheduled_at)
      end

      it "enqueues the release at the scheduled time" do
        result
        publication.reload
        expect_job_enqueued(
          job: :publish_blog_revision,
          args: {
            publication_id: publication.id,
            token: publication.schedule_token,
          },
          at: publication.scheduled_at,
        )
      end

      it "logs the schedule" do
        result
        expect(UserHistory.find_by(custom_type: "blog_schedule")).to have_attributes(
          acting_user_id: acting_user.id,
          topic_id: topic.id,
        )
      end
    end
  end
end
