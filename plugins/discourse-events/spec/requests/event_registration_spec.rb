# frozen_string_literal: true

RSpec.describe "Event registration" do
  fab!(:host, :user)
  fab!(:member, :user)
  fab!(:event) { Fabricate(:event, user: host) }
  let(:definition) do
    {
      "title" => "Workshop registration",
      "description" => "Help us prepare.",
      "fields" => [
        {
          "id" => "track",
          "label" => "Track",
          "type" => "radio",
          "required" => true,
          "choices" => [{ "id" => "design", "label" => "Design" }],
        },
        { "id" => "consent", "label" => "I agree", "type" => "checkbox", "required" => true },
        {
          "id" => "days",
          "label" => "Days",
          "type" => "checkboxes",
          "required" => false,
          "choices" => [
            { "id" => "fri", "label" => "Friday" },
            { "id" => "sat", "label" => "Saturday" },
          ],
        },
      ],
    }
  end
  let(:answers) { { "track" => "design", "consent" => true, "days" => %w[sat fri] } }
  let(:payload) do
    { key: SecureRandom.uuid, revision: event.reload.registration_revision, answers: }
  end
  let(:url) { "/discourse-post-event/events/#{event.id}/invitees.json" }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    event.update!(registration_form: definition)
    sign_in(member)
  end

  it "snapshots the library form and returns only the questions to the member" do
    Jobs.run_immediately!
    admin = Fabricate(:admin)
    form = DiscourseEvents::Events::RegistrationForm.create!(definition:)
    post =
      create_post_with_event(
        admin,
        %(status="public" registrationFormId="#{form.id}"),
        2.days.from_now,
      )
    expect(post.event).to have_attributes(
      registration_form_id: form.id,
      registration_form: definition,
    )
    form.update!(definition: definition.merge("title" => "Revised workshop"))
    post.revise(admin, { raw: post.raw + "\nNew room." })
    expect(post.reload.event.registration_form).to eq(definition)
    later_post =
      create_post_with_event(
        admin,
        %(status="public" registrationFormId="#{form.id}"),
        3.days.from_now,
      )
    expect(later_post.event.registration_form.fetch("title")).to eq("Revised workshop")
    freeze_time 5.days.from_now
    form.trash!(admin)
    post.revise(admin, { raw: post.raw + "\nRoom confirmed." })
    expect(post.reload.event.registration_form).to eq(definition)
    get "/discourse-post-event/events/#{post.id}.json"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["event"].fetch("registration_form")).to eq(
      definition.slice("fields"),
    )
    expect(response.parsed_body["event"]["registration_revision"]).to be_present
    expect(response.parsed_body["event"]["can_export_registrations"]).to be(false)
  end

  it "leaves tracking off by default and reports account-only registrations to the host PM" do
    Jobs.run_immediately!
    admin = Fabricate(:admin)
    event_post = create_post_with_event(admin, 'status="public"', 2.days.from_now)
    tracked_event = event_post.event
    attend_url = "/discourse-post-event/events/#{tracked_event.id}/invitees.json"
    post attend_url, params: { invitee: { status: "going" } }
    expect(response).to have_http_status(:ok)
    expect(tracked_event.registrations).to be_empty
    expect(tracked_event.reload.registration_topic_id).to be_nil

    original_raw = event_post.raw
    event_post.revise(
      admin,
      { raw: original_raw.sub('status="public"', 'status="public" registrationForm="account"') },
    )
    expect(tracked_event.reload.registration_form).to include(
      "builtin" => "account",
      "fields" => [],
    )
    get "/discourse-post-event/events/#{tracked_event.id}.json"
    serialized = response.parsed_body.fetch("event")
    expect(serialized.fetch("registration_form")).to eq("builtin" => "account", "fields" => [])
    revision = serialized.fetch("registration_revision")
    registrants = Fabricate.times(2, :user)
    registrants.each do |registrant|
      sign_in(registrant)
      registration = { key: SecureRandom.uuid, revision:, answers: { email: "unused@example.com" } }
      post attend_url, params: { invitee: { status: "going", registration: registration.to_json } }
      expect(response).to have_http_status(:ok)
    end
    submissions = tracked_event.registrations.order(:id)
    expect(submissions.pluck(:username, :email, :answers)).to eq(
      registrants.map { |u| [u.username, u.email, {}] },
    )
    reports = Topic.find(tracked_event.reload.registration_topic_id).posts.order(:post_number)
    expect(reports.pluck(:id)).to eq(submissions.pluck(:report_post_id))
    registrants
      .zip(reports)
      .each do |registrant, report|
        expect(report.raw).to include(registrant.username)
        expect(report.raw).not_to include(registrant.email)
      end
    csv = Jobs::ExportCsvFile.new
    csv.current_user = admin
    csv.extra = { id: tracked_event.id }
    expect(csv.event_registrations_export.to_a.map(&:second)).to eq(registrants.map(&:email))

    event_post.revise(admin, { raw: original_raw })
    expect(tracked_event.reload.registration_form).to be_nil
    expect(tracked_event.registrations.count).to eq(2)
  end

  it "keeps a previously published inline form during post edits" do
    admin = Fabricate(:admin)
    legacy = Fabricate(:event, user: admin, registration_form: definition)
    post = legacy.post
    get "/discourse-post-event/events/#{post.id}.json"
    expect(response.parsed_body["event"].fetch("registration_form")).to eq(
      definition.slice("fields"),
    )
    sign_in(admin)
    get "/discourse-post-event/events/#{post.id}.json"
    expect(response.parsed_body["event"].fetch("registration_form")).to eq(definition)
    encoded = ERB::Util.url_encode(definition.to_json)
    raw =
      %([event start="#{legacy.starts_at.iso8601}" status="public" registrationForm="#{encoded}"]\n[/event])
    post.update_column(:raw, raw)
    Jobs.run_immediately!
    post.revise(admin, { raw: raw + "\nNew room." })
    expect(post.reload.raw).to end_with("New room.")
    expect(legacy.reload.registration_form).to eq(definition)
  end

  it "rejects unknown form references and new inline forms" do
    admin = Fabricate(:admin)
    sign_in(admin)
    encoded = ERB::Util.url_encode(definition.to_json)
    removed = DiscourseEvents::Events::RegistrationForm.create!(definition:)
    removed.trash!(admin)
    [
      %(registrationFormId="99999999"),
      %(registrationFormId="#{removed.id}"),
      %(registrationForm="#{encoded}"),
    ].each do |attribute|
      post "/posts.json",
           params: {
             title: "Workshop registration test",
             raw:
               %([event start="#{2.days.from_now.iso8601}" status="public" #{attribute}]\n[/event]),
           }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.fetch("errors").join).to include(
        I18n.t("discourse_post_event.errors.models.event.unknown_registration_form"),
      )
    end
  end

  it "authorizes the CSV export for the creator and listed hosts" do
    cohost = Fabricate(:user)
    event.update!(host_user_ids: [cohost.id])
    params = { entity: "event_registrations", args: { id: event.id } }
    post("/export_csv/export_entity.json", params:)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Jobs::ExportCsvFile.jobs).to be_empty
    [host, cohost].each do |recipient|
      sign_in(recipient)
      post("/export_csv/export_entity.json", params:)
      expect(response).to have_http_status(:ok)
      expect(Jobs::ExportCsvFile.jobs.last.fetch("args").first).to include(
        "entity" => "event_registrations",
        "user_id" => recipient.id,
      )
    end
  end

  it "accepts an explicit empty response to an optional form" do
    field = { "id" => "notes", "type" => "text", "label" => "Notes", "required" => false }
    event.update!(registration_form: definition.merge("fields" => [field]))
    post url,
         params: {
           invitee: {
             status: "going",
             registration: payload.merge(answers: {}).to_json,
           },
         }
    expect(response).to have_http_status(:ok)
    expect(event.registrations.sole.answers).to eq({})
  end

  it "keeps a committed RSVP and recovers the host PM when the queue is unavailable" do
    Jobs::ReportEventRegistrations.stubs(:client_push).raises(Redis::CannotConnectError)
    post url, params: { invitee: { status: "going", registration: payload.to_json } }
    expect(response).to have_http_status(:ok)
    expect(event.invitees.sole).to be_going
    submission = event.registrations.sole
    expect(submission.report_post_id).to be_nil
    Jobs::ReportEventRegistrations.unstub(:client_push)

    recovery = Jobs::RetryEventRegistrationReports.new
    recovery.execute({})
    expect(Jobs::ReportEventRegistrations.jobs).to be_empty
    freeze_time 15.minutes.from_now
    recovery.execute({})
    expect(Jobs::ReportEventRegistrations.jobs.sole.fetch("args").first.fetch("event_id")).to eq(
      event.id,
    )
    Jobs::ReportEventRegistrations.drain
    expect(submission.reload.report_post_id).to be_present
    expect(event.registrations.unreported).to be_empty
    recovery.execute({})
    expect(Jobs::ReportEventRegistrations.jobs).to be_empty
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    expect(Topic.find(event.reload.registration_topic_id).posts.count).to eq(1)
  end

  it "requires a question in custom event forms and leaves display text out of reports" do
    text = { "id" => "welcome", "type" => "display_text", "content" => "Meet at the entrance." }
    expect(event.update(registration_form: definition.merge("fields" => [text]))).to be(false)
    expect(event.errors[:registration_form]).to include(
      I18n.t("discourse_post_event.errors.models.event.registration_form_needs_field"),
    )
    question = { "id" => "arrival", "type" => "text", "label" => "Arrival", "required" => false }
    event.update!(registration_form: definition.merge("fields" => [text, question]))
    post url,
         params: {
           invitee: {
             status: "going",
             registration: payload.merge(answers: { welcome: "unused" }).to_json,
           },
         }
    expect(response).to have_http_status(:ok)
    registration = event.registrations.sole
    expect(registration.answers).to eq({})
    expect(event.invitees.sole).to be_going
    expect(registration.report_body).not_to include(text.fetch("content"), "unused")
    report = Jobs::ExportCsvFile.new
    report.current_user = host
    report.extra = { id: event.id }
    expect(report.get_header("event_registrations")).to eq(
      %w[username submitted_at occurrence_starts_at recurring Arrival],
    )
    expect(report.event_registrations_export.to_a.sole.size).to eq(5)
  end

  it "records the signed-in member’s account email separately from a form question named email" do
    field = { "id" => "email", "type" => "text", "label" => "Team contact", "required" => false }
    event.update!(registration_form: definition.merge("fields" => [field]))
    contact = "team@example.com"
    submitted =
      payload.merge(email: contact, answers: { "email" => contact, "_accountEmail" => contact })
    post url, params: { invitee: { status: "going", registration: submitted.to_json } }
    expect(response).to have_http_status(:ok)
    expect(event.registrations.sole).to have_attributes(
      email: member.email,
      answers: {
        "email" => contact,
      },
    )
  end

  it "rejects an obsolete revision and an invalid choice without recording attendance" do
    old = payload.to_json
    event.update!(registration_form: definition.merge("title" => "New form"))
    post url, params: { invitee: { status: "going", registration: old } }
    expect(response).to have_http_status(:unprocessable_entity)
    post url,
         params: {
           invitee: {
             status: "going",
             registration:
               payload.merge(
                 revision: event.reload.registration_revision,
                 answers: answers.merge("track" => "missing"),
               ).to_json,
           },
         }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(event.invitees).to be_empty
    expect(event.registrations).to be_empty
  end

  it "keeps the chosen occurrence and scope when an existing invitee registers" do
    event.update!(recurrence: "every_week")
    post url, params: { invitee: { status: "interested" } }
    occurrence = event.calculate_next_occurrence_from(event.starts_at + 1.day).fetch(:starts_at)
    put "/discourse-post-event/events/#{event.id}/invitees/#{event.invitees.sole.id}.json",
        params: {
          invitee: {
            status: "going",
            recurring: true,
            registration: payload.merge(occurrence: occurrence.iso8601).to_json,
          },
        }
    expect(response).to have_http_status(:ok)
    expect(event.invitees.sole).to be_going
    expect(event.registrations.sole).to have_attributes(
      occurrence_starts_at: occurrence,
      recurring: true,
    )
  end

  it "requires an explicit valid submission for either attendance operation" do
    post url, params: { invitee: { status: "going" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(event.invitees).to be_empty
    post url, params: { invitee: { status: "interested" } }
    expect(response).to have_http_status(:ok)
    invitee = event.invitees.sole
    put "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json",
        params: {
          invitee: {
            status: "going",
            registration: payload.merge(answers: answers.merge("consent" => false)).to_json,
          },
        }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(invitee.reload.status).to eq(DiscourseEvents::Events::Invitee.statuses[:interested])
    expect(event.registrations).to be_empty
  end

  it "removes the old account email line from generated PMs and revisions, preserving answers" do
    definition["fields"] << {
      "id" => "contact",
      "type" => "text",
      "label" => "Team contact",
      "required" => false,
    }
    event.update!(registration_form: definition)
    # The member can still choose to enter an address in a free-text answer.
    submission = payload.merge(answers: answers.merge("contact" => member.email))
    post url, params: { invitee: { status: "going", registration: submission.to_json } }
    expect(response).to have_http_status(:ok)
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    post = Post.find(event.registrations.sole.report_post_id)
    clean = post.raw
    legacy = clean.sub("    Submitted at:", "    Email: #{member.email}\n    Submitted at:")
    cooked = post.cook(legacy, topic_id: post.topic_id)
    post.update_columns(raw: legacy, cooked:)
    revision =
      PostRevision.create!(
        post:,
        user: Discourse.system_user,
        number: 2,
        modifications: {
          "raw" => [legacy, legacy],
          "cooked" => [cooked, cooked],
        },
      )
    2.times { Jobs::RedactEventRegistrationReportEmails.new.execute_onceoff({}) }
    expect(post.reload.raw).to eq(clean)
    expect(post.cooked).to include("Team contact: #{member.email}")
    expect(post.cooked).not_to include("Email: #{member.email}")
    expect(revision.reload.modifications.fetch("raw")).to eq([clean, clean])
    expect(revision.modifications.fetch("cooked").join).not_to include("Email: #{member.email}")
  end

  it "stores each submission once and reports it to the same private topic" do
    moderator = Fabricate(:moderator)
    SiteSetting.moderators_view_emails = true
    event.update!(recurrence: "every_week")
    event.update!(host_user_ids: [moderator.id])
    first = payload.to_json
    2.times do
      post url, params: { invitee: { status: "going", recurring: true, registration: first } }
      expect(response).to have_http_status(:ok)
    end
    registration = event.registrations.sole
    expect(registration).to have_attributes(
      username: member.username,
      email: member.email,
      answers:,
      recurring: true,
    )
    second = Fabricate(:user)
    sign_in(second)
    post url,
         params: {
           invitee: {
             status: "going",
             registration: payload.merge(key: SecureRandom.uuid).to_json,
           },
         }
    expect(response).to have_http_status(:ok)
    2.times { Jobs::ReportEventRegistrations.new.execute(event_id: event.id) }
    topic = Topic.find(event.reload.registration_topic_id)
    expect(topic).to be_private_message
    expect(topic.allowed_users.pluck(:id)).to include(*event.registration_host_ids)
    expect(topic.allowed_users).not_to include(member, second)
    expect(topic.posts.order(:post_number).pluck(:raw)).to match(
      [
        a_string_including(member.username, "Design", registration.created_at.utc.iso8601),
        a_string_including(second.username, "Design", "Days: Friday, Saturday"),
      ],
    )
    expect(topic.posts.pluck(:raw, :cooked).flatten.join).not_to match(
      /#{Regexp.escape(member.email)}|#{Regexp.escape(second.email)}/,
    )
    [host, moderator].each do |recipient|
      report = Jobs::ExportCsvFile.new
      report.current_user = recipient
      report.extra = { id: event.id }
      header = report.get_header("event_registrations")
      expect(header).to end_with("Track", "I agree", "Days")
      expect(header).not_to include("email")
      rows = report.event_registrations_export.to_a
      expect(rows.map(&:first)).to contain_exactly(member.username, second.username)
      expect(rows.flatten).not_to include(member.email, second.email)
      expect(rows.map(&:length).uniq).to eq([header.size])
      expect(rows.map(&:last).uniq).to eq(["Friday, Saturday"])
    end
    admin = Fabricate(:admin)
    event.update!(host_user_ids: [admin.id])
    admin_report = Jobs::ExportCsvFile.new
    admin_report.current_user = admin
    admin_report.extra = { id: event.id }
    expect(admin_report.get_header("event_registrations")).to start_with(
      "username",
      "email",
      "submitted_at",
    )
    expect(admin_report.event_registrations_export.to_a.map(&:second)).to contain_exactly(
      member.email,
      second.email,
    )
    event.update!(host_user_ids: [])
    expect(topic.reload.allowed_users.pluck(:id)).to contain_exactly(
      host.id,
      Discourse.system_user.id,
    )
    expect(member.guardian.can_export_entity?("event_registrations", nil, id: event.id)).to eq(
      false,
    )
  end
end
