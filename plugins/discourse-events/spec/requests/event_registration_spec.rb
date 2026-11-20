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
      ],
    }
  end
  let(:answers) { { "track" => "design", "consent" => true } }
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

  it "saves the form through event markup and returns it to the member without responses" do
    Jobs.run_immediately!
    admin = Fabricate(:admin)
    encoded = ERB::Util.url_encode(definition.to_json)
    post =
      create_post_with_event(
        admin,
        %(status="public" registrationForm="#{encoded}"),
        2.days.from_now,
      )
    expect(post.event.registration_form).to eq(definition)
    get "/discourse-post-event/events/#{post.id}.json"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["event"]).to include("registration_form" => definition)
    expect(response.parsed_body["event"]["registration_revision"]).to be_present
    expect(response.parsed_body["event"]["can_export_registrations"]).to be(false)
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
    event.update!(registration_form: definition.merge("fields" => []))
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

  it "stores each submission once and reports it to the same private topic" do
    event.update!(recurrence: "every_week")
    event.update!(host_user_ids: [Fabricate(:user).id])
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
        a_string_including(member.email, "Design", registration.created_at.utc.iso8601),
        a_string_including(second.email, "Design"),
      ],
    )
    report = Jobs::ExportCsvFile.new
    report.current_user = host
    report.extra = { id: event.id }
    expect(report.get_header("event_registrations")).to end_with("Track", "I agree")
    expect(report.event_registrations_export.to_a.map(&:second)).to contain_exactly(
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
