# frozen_string_literal: true

RSpec.describe "Event registration account cleanup" do
  fab!(:admin)
  fab!(:member, :user)
  fab!(:event)
  fab!(:registration) { Fabricate(:event_registration, event:, member:) }
  let(:redacted) { I18n.t("event_registration.submission_erased") }

  it "erases pending and reported submissions and PM history when an account is anonymized" do
    other = Fabricate(:event_registration, event:)
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    report = Post.find(registration.reload.report_post_id)
    report.revise(
      Discourse.system_user,
      { raw: "#{report.raw}\nOld note." },
      force_new_version: true,
    )
    expect(report.revisions).to be_present
    Fabricate(:post_localization, post: report)
    other_post = Post.find(other.reload.report_post_id)
    original = other_post.raw
    Fabricate(:event_registration, event:, member:)

    SiteSetting.discourse_events_enabled = false
    UserAnonymizer.make_anonymous(member, admin)
    later = Fabricate(:event_registration, event:, member:, created_at: 1.minute.from_now)
    Jobs::EraseEventRegistrations.drain
    expect(event.registrations).to contain_exactly(other, later)
    expect(report.reload.raw).to eq(redacted)
    expect(report.cooked).to include(redacted)
    expect(report.revisions).to be_empty
    expect(report.localizations).to be_empty
    expect(report.topic.reload.excerpt).not_to include(
      "Meet me by the door.",
      registration.username,
    )
    expect(other_post.reload.raw).to eq(original)
    expect(other_post.topic_id).to eq(report.topic_id)
    SiteSetting.discourse_events_enabled = true
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    expect(report.topic.posts.count).to eq(3)
  end

  it "recovers a missed erasure after bulk deletion and keeps the host’s replies" do
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    report = Post.find(registration.reload.report_post_id)
    reply = create_post(user: event.post.user, topic: report.topic, raw: "I have booked the venue.")
    event.registrations.delete_all
    DiscourseEvents::Events::Event.where(id: event.id).delete_all
    expect(DiscourseEvents::Events::Registration.exists?(registration.id)).to be(false)
    report.trash!(admin)
    report.topic.trash!(admin)
    Jobs::EraseEventRegistrations.stubs(:client_push).raises(Redis::CannotConnectError)
    expect(UserDestroyer.new(admin).destroy(member)).to be_destroyed
    expect(Jobs::EraseEventRegistrations.jobs).to be_empty
    Jobs::EraseEventRegistrations.unstub(:client_push)
    Jobs::RetryEventRegistrationErasures.new.execute({})
    expect(Jobs::EraseEventRegistrations.jobs.sole.fetch("args").first.fetch("user_id")).to eq(
      member.id,
    )
    Jobs::EraseEventRegistrations.drain
    expect(Post.with_deleted.find(report.id).raw).to eq(redacted)
    expect(reply.reload.raw).to eq("I have booked the venue.")
    expect(
      PostCustomField.exists?(
        post_id: report.id,
        name: DiscourseEvents::Events::Registration::REPORT_USER_FIELD,
      ),
    ).to be(false)
  end

  it "recovers older deleted and anonymized accounts while preserving later submissions" do
    registration.update_columns(user_id: -99_999)
    old = Fabricate(:event_registration, event:, member:, created_at: 2.days.ago)
    history =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:anonymize_user],
        target_user_id: member.id,
        created_at: 1.day.ago,
      )
    recent =
      Fabricate(:event_registration, event:, member:, created_at: history.created_at + 1.hour)
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    old_report_id = old.reload.report_post_id
    old.delete
    sweep = Jobs::RetryEventRegistrationErasures.new
    sweep.execute({})
    Jobs::EraseEventRegistrations.drain
    sweep.execute({})
    expect(Jobs::EraseEventRegistrations.jobs).to be_empty
    expect(event.registrations).to contain_exactly(recent)
    expect(Post.find(old_report_id).raw).to eq(redacted)
  end
end
