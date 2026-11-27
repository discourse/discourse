# frozen_string_literal: true

RSpec.describe Admin::DiscourseEvents::SubmissionsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:host, :user)
  fab!(:member, :user)
  fab!(:event) { Fabricate(:event, user: host) }
  let(:url) { "/admin/plugins/discourse-events/submissions" }
  let(:definition) do
    {
      "title" => "Workshop form",
      "fields" => [{ "id" => "notes", "type" => "text", "label" => "Notes", "required" => false }],
    }
  end

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    event.update!(registration_form: definition)
  end

  it "shows an admin aggregate activity without disclosing registrants, answers, or host report access" do
    host.update!(uploaded_avatar_id: Fabricate(:upload).id)
    registration =
      event.registrations.create!(
        user_id: member.id,
        username: member.username,
        email: member.email,
        answers: {
        },
        definition:,
        recurring: false,
        occurrence_starts_at: event.starts_at,
        submission_key: SecureRandom.uuid,
      )
    Jobs::ReportEventRegistrations.new.execute(event_id: event.id)
    empty_event = Fabricate(:event, user: host, registration_form: definition)
    event.update!(registration_form: nil)
    sign_in(admin)
    get url
    expect(response).to have_http_status(:ok)
    get "#{url}.json"
    expect(response).to have_http_status(:ok)
    rows = response.parsed_body.fetch("events")
    expect(rows.pluck("id")).to eq([event.id, empty_event.id])
    expect(rows.first).to include(
      "host_usernames" => [host.username],
      "submission_count" => 1,
      "can_export" => false,
      "report_topic_id" => nil,
    )
    expect(Time.iso8601(rows.first.fetch("latest_submission_at")).to_i).to eq(
      registration.created_at.to_i,
    )
    expect(rows.last).to include(
      "form_title" => "Workshop form",
      "submission_count" => 0,
      "latest_submission_at" => nil,
    )
    expect(response.body).not_to include(member.email, member.username, "answers")
    expect(admin.guardian.can_export_event_registrations?(event)).to be(false)
    event.update!(host_user_ids: [host.id, admin.id])
    get "#{url}.json"
    expect(response.parsed_body.fetch("events").first).to include(
      "hosts" => [
        { "username" => host.username, "avatar_template" => host.avatar_template },
        { "username" => admin.username, "avatar_template" => admin.avatar_template },
      ],
      "host_usernames" => [host.username, admin.username],
      "can_export" => true,
      "report_topic_id" => event.reload.registration_topic_id,
    )
  end

  it "filters by the built-in form independently of custom and untracked events" do
    account_form = DiscourseEvents::Events::RegistrationForm.account_only_definition
    built_in = Fabricate(:event, user: host, registration_form: account_form)
    Fabricate(:event, user: host)
    event.update!(registration_form: definition.merge("title" => account_form.fetch("title")))
    sign_in(admin)
    get "#{url}.json", params: { form_id: "account" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("events").pluck("id", "form_title")).to eq(
      [[built_in.id, account_form.fetch("title")]],
    )
  end

  it "restricts even the aggregate view to administrators" do
    [nil, host, moderator].each do |user|
      sign_in(user) if user
      get "#{url}.json"
      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include("submission_count")
    end
  end

  it "paginates events with the same latest submission time in a stable order" do
    other = Fabricate(:event, user: host, registration_form: definition)
    sign_in(admin)
    stub_const(described_class, :PAGE_SIZE, 1) do
      get "#{url}.json"
      expect(response.parsed_body).to include("previous_page" => nil, "next_page" => 2)
      expect(response.parsed_body.fetch("events").pluck("id")).to eq([other.id])
      get "#{url}.json", params: { page: 2 }
      expect(response.parsed_body).to include("previous_page" => 1, "next_page" => nil)
      expect(response.parsed_body.fetch("events").pluck("id")).to eq([event.id])
    end
  end

  it "searches displayed event and form names before paginating, treating wildcards literally" do
    event.update!(name: "Spring open house")
    event.post.topic.update!(title: "Organizers meeting")
    open_form = definition.merge("title" => "Open house 50%_off")
    other = Fabricate(:event, user: host, registration_form: open_form)
    other.post.topic.update!(title: "Community summer picnic")
    Fabricate(:event, user: host, registration_form: definition)
    sign_in(admin)

    stub_const(described_class, :PAGE_SIZE, 1) do
      get "#{url}.json", params: { search: " OPEN HOUSE " }
      expect(response.parsed_body.fetch("events").pluck("id")).to eq([other.id])
      expect(response.parsed_body["next_page"]).to eq(2)
      get "#{url}.json", params: { search: "open house", page: 2 }
      expect(response.parsed_body.fetch("events").pluck("id")).to eq([event.id])
    end

    get "#{url}.json", params: { search: "picnic" }
    expect(response.parsed_body.fetch("events").pluck("id")).to eq([other.id])
    get "#{url}.json", params: { search: "%_" }
    expect(response.parsed_body.fetch("events").pluck("id")).to eq([other.id])
    get "#{url}.json", params: { search: "Organizers meeting" }
    expect(response.parsed_body.fetch("events")).to be_empty
  end

  it "paginates only events linked to the selected library form, including those with no submissions" do
    fields = [{ "id" => "name", "label" => "Name", "type" => "text", "required" => false }]
    form =
      DiscourseEvents::Events::RegistrationForm.create!(
        definition: definition.merge("fields" => fields),
      )
    event.update!(registration_form_id: form.id)
    other =
      Fabricate(
        :event,
        user: host,
        registration_form_id: form.id,
        registration_form: form.definition,
      )
    Fabricate(:event, user: host, registration_form: definition)
    form.update!(definition: form.definition.merge("title" => "Renamed form"))

    sign_in(admin)
    event.registrations.create!(
      user_id: member.id,
      username: member.username,
      email: member.email,
      answers: {
        "name" => "Sam",
      },
      definition: form.definition,
      recurring: false,
      occurrence_starts_at: event.starts_at,
      submission_key: SecureRandom.uuid,
    )
    freeze_time 3.days.from_now
    form.trash!(admin)
    get "/discourse-post-event/registration-forms.json", params: { for_reports: true }
    expect(response.parsed_body.fetch("registration_forms").pluck("id")).to include(form.id)
    get "#{url}.json", params: { search: "renamed" }
    expect(response.parsed_body.fetch("events").pluck("id")).to contain_exactly(event.id, other.id)
    get "#{url}.json", params: { form_id: form.id, search: "workshop" }
    expect(response.parsed_body.fetch("events").pluck("id")).to contain_exactly(event.id, other.id)
    get "#{url}.json", params: { form_id: form.id, search: "unrelated" }
    expect(response.parsed_body.fetch("events")).to be_empty
    stub_const(described_class, :PAGE_SIZE, 1) do
      get "#{url}.json", params: { form_id: form.id }
      expect(response.parsed_body).to include("next_page" => 2)
      expect(response.parsed_body.fetch("events").pluck("id", "url")).to eq(
        [[event.id, event.post.topic.relative_url(event.post.post_number)]],
      )
      expect(response.parsed_body.fetch("events").first.fetch("submission_count")).to eq(1)
      get "#{url}.json", params: { form_id: form.id, page: 2 }
      expect(response.parsed_body.fetch("events").pluck("id")).to eq([other.id])
      expect(response.parsed_body).to include("previous_page" => 1, "next_page" => nil)
    end
  end
end
