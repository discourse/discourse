# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::CsvBulkInvite) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin, :admin)
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }
    fab!(:invited_user, :user)

    let(:file) { csv_file("#{invited_user.username},going\n") }
    let(:params) { { event_id: event.id, file: } }
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    def csv_file(content)
      tempfile = Tempfile.new("invites.csv")
      tempfile.write(content)
      tempfile.rewind
      Struct.new(:tempfile).new(tempfile)
    end

    context "when contract is invalid" do
      let(:params) { { event_id: nil, file: } }

      it { is_expected.to fail_a_contract }
    end

    context "when event does not exist" do
      let(:params) { { event_id: -1, file: } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when user cannot edit the post" do
      fab!(:lurker, :user)
      let(:dependencies) { { guardian: lurker.guardian } }

      it { is_expected.to fail_a_policy(:can_edit_post) }

      context "without a file" do
        let(:file) { nil }

        it "fails the authorization policy before checking the file" do
          is_expected.to fail_a_policy(:can_edit_post)
        end
      end
    end

    context "when user can edit the post but cannot create events" do
      fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:author_topic) { Fabricate(:topic, user: author) }
      fab!(:author_post) { Fabricate(:post, user: author, topic: author_topic) }
      fab!(:author_event) { Fabricate(:event, post: author_post) }
      fab!(:disallowed_group, :group)

      let(:params) { { event_id: author_event.id, file: } }
      let(:dependencies) { { guardian: author.guardian } }

      before { SiteSetting.discourse_post_event_allowed_on_groups = disallowed_group.id.to_s }

      it { is_expected.to fail_a_policy(:can_create_event) }
    end

    context "without a file" do
      let(:file) { nil }

      it { is_expected.to fail_a_policy(:file_present) }
    end

    context "with an empty file" do
      let(:file) { csv_file("") }

      it { is_expected.to fail_to_find_a_model(:invitees) }
    end

    context "when enqueueing the job fails" do
      before { Jobs.stubs(:enqueue).raises(StandardError.new("boom")) }

      it { is_expected.to fail_with_exception }
    end

    context "when everything is valid" do
      before { Jobs.run_later! }

      it { is_expected.to run_successfully }

      it "enqueues the bulk invite job with the parsed invitees" do
        expect_enqueued_with(
          job: :discourse_post_event_bulk_invite,
          args: {
            event_id: event.id,
            invitees: [{ "identifier" => invited_user.username, "attendance" => "going" }],
            current_user_id: admin.id,
          },
        ) { result }
      end
    end
  end
end
