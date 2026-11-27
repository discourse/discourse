# frozen_string_literal: true

RSpec.describe DiscourseEvents::RegistrationFormsController do
  fab!(:admin)
  fab!(:host, :user)
  fab!(:hosts, :group) { Fabricate(:group).tap { |group| group.add(host) } }
  let(:url) { "/discourse-post-event/registration-forms" }
  let(:definition) do
    {
      "title" => "Workshop",
      "description" => "Register",
      "fields" => [
        {
          "id" => "guests",
          "label" => "Guests",
          "type" => "number",
          "required" => false,
          "description" => "Include yourself in the count.",
        },
      ],
    }
  end

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = hosts.id.to_s
  end

  it "lets admins create and edit a form for event hosts to select" do
    definition["fields"].unshift(
      { "id" => "welcome", "type" => "display_text", "content" => "Please register your group." },
    )
    sign_in(admin)
    post "#{url}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch("id")
    put "#{url}/#{id}.json",
        params: {
          definition: definition.merge("title" => "Conference"),
        },
        as: :json
    expect(response).to have_http_status(:ok)
    sign_in(host)
    get "#{url}.json"
    expect(response.parsed_body.fetch("registration_forms")).to eq(
      [{ "id" => id, "title" => "Conference", "description" => definition.fetch("description") }],
    )
    get "#{url}/#{id}.json"
    expect(response.parsed_body.fetch("definition")).to eq(
      definition.merge("title" => "Conference"),
    )
    put "#{url}/#{id}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "lets an eligible host manage their own forms and keeps ownership on the server" do
    sign_in(host)
    get "#{url}/new"
    expect(response).to have_http_status(:ok)
    post "#{url}.json", params: { definition:, created_by_id: admin.id }, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch("id")
    expect(DiscourseEvents::Events::RegistrationForm.find(id).created_by).to eq(host)
    get "#{url}/#{id}/edit"
    expect(response).to have_http_status(:ok)
    put "#{url}/#{id}.json",
        params: {
          definition: definition.merge("title" => "Revised"),
        },
        as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("definition", "title")).to eq("Revised")
    get "#{url}/mine.json"
    expect(response.parsed_body.fetch("registration_forms").pluck("id")).to eq([id])
    get "#{url}.json", params: { include_usage: true }
    expect(response).to have_http_status(:forbidden)

    SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:staff].to_s
    delete "#{url}/#{id}.json"
    expect(response).to have_http_status(:forbidden)
    get "#{url}.json"
    expect(response).to have_http_status(:forbidden)
    post "#{url}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "protects other creators' forms and ownerless forms from host edits and removal" do
    forms = DiscourseEvents::Events::RegistrationForm
    other_host = Fabricate(:user)
    hosts.add(other_host)
    owned = forms.create!(definition:, created_by: host)
    admin_form = forms.create!(definition:, created_by: admin)
    old_form = forms.create!(definition:)
    sign_in(other_host)
    get "#{url}/mine.json"
    expect(response.parsed_body.fetch("registration_forms")).to be_empty
    get "#{url}.json"
    expect(response.parsed_body.fetch("registration_forms").pluck("id")).to contain_exactly(
      owned.id,
      old_form.id,
      admin_form.id,
    )
    [owned, old_form, admin_form].each do |form|
      get "#{url}/#{form.id}/edit.json"
      expect(response).to have_http_status(:forbidden)
      put "#{url}/#{form.id}.json",
          params: {
            definition: definition.merge("title" => "Changed"),
          },
          as: :json
      expect(response).to have_http_status(:forbidden)
      delete "#{url}/#{form.id}.json"
      expect(response).to have_http_status(:forbidden)
    end
    sign_in(admin)
    delete "#{url}/#{old_form.id}.json"
    expect(response).to have_http_status(:no_content)
    sign_in(host)
    delete "#{url}/#{owned.id}.json"
    expect(response).to have_http_status(:no_content)
    get "#{url}.json"
    expect(response.parsed_body.fetch("registration_forms").pluck("id")).to eq([admin_form.id])
    get "#{url}/mine.json"
    expect(response.parsed_body.fetch("registration_forms")).to be_empty
  end

  it "requires event creation permission and enabled events for non-admins to create forms" do
    post "#{url}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:forbidden)
    sign_in(Fabricate(:user))
    get "#{url}/new"
    expect(response).to have_http_status(:forbidden)
    post "#{url}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:forbidden)
    sign_in(host)
    SiteSetting.discourse_post_event_enabled = false
    post "#{url}.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects invalid forms and serves direct admin page reloads" do
    sign_in(admin)
    post "#{url}.json", params: { definition: definition.merge("title" => "") }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{url}.json", params: { definition: definition.merge("fields" => []) }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    note = { id: "note", type: "display_text", content: "Bring lunch." }
    post "#{url}.json", params: { definition: definition.merge("fields" => [note]) }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join).to include(
      I18n.t("discourse_post_event.errors.models.event.registration_form_needs_field"),
    )
    %w[registration-forms registration-forms/new registration-forms/1/edit].each do |path|
      get "/admin/plugins/discourse-events/#{path}"
      expect(response).to have_http_status(:ok)
    end
  end

  it "counts custom fields and linked events for the admin library" do
    forms = DiscourseEvents::Events::RegistrationForm
    used = forms.create!(definition:, created_by: host)
    unused = forms.create!(definition: definition.merge("title" => "Unused"))
    Fabricate(
      :event,
      registration_form_id: used.id,
      registration_form: definition,
      recurrence: "every_week",
    )
    Fabricate(:event, registration_form_id: used.id, registration_form: definition)
    Fabricate(
      :event,
      registration_form_id: used.id,
      registration_form: definition,
      deleted_at: Time.current,
    )
    Fabricate(:event, registration_form: definition)
    built_in = forms.account_only_definition
    Fabricate(:event, registration_form: built_in, recurrence: "every_week")
    Fabricate(:event, registration_form: built_in, deleted_at: Time.current)
    used.update!(
      definition:
        definition.merge(
          "title" => "Renamed",
          "fields" => definition["fields"] + [definition["fields"].first.merge("id" => "age")],
        ),
    )

    sign_in(admin)
    get "#{url}.json", params: { include_usage: true }
    expect(response).to have_http_status(:ok)
    expect(
      response.parsed_body.fetch("registration_forms").pluck("id", "field_count", "event_count"),
    ).to eq([["account", 0, 1], [used.id, 2, 2], [unused.id, 1, 0]])
    expect(response.parsed_body.fetch("registration_forms").first.fetch("builtin")).to be(true)
    summaries =
      response.parsed_body.fetch("registration_forms").index_by { |form| form.fetch("id") }
    expect(summaries.fetch(used.id).fetch("created_by")).to eq(
      "username" => host.username,
      "avatar_template" => host.avatar_template,
    )
    expect(summaries.fetch(unused.id)["created_by"]).to be_nil
    put "#{url}/account.json", params: { definition: }, as: :json
    expect(response).to have_http_status(:not_found)
    delete "#{url}/account.json"
    expect(response).to have_http_status(:not_found)
    sign_in(host)
    get "#{url}.json", params: { include_usage: true }
    expect(response).to have_http_status(:forbidden)
  end

  it "blocks owners and admins from deleting a form until all linked events end" do
    freeze_time Time.utc(2030, 1, 7, 12)
    form = DiscourseEvents::Events::RegistrationForm.create!(definition:, created_by: host)
    link = { registration_form_id: form.id, registration_form: definition }
    Fabricate(:event, **link, original_starts_at: 2.hours.ago, original_ends_at: 1.hour.from_now)
    Fabricate(:event, **link, original_starts_at: 1.day.from_now, closed: true)
    Fabricate(:event, **link, original_starts_at: 1.month.from_now, deleted_at: Time.current)
    sign_in(host)
    get "#{url}/mine.json"
    expect(response.parsed_body.fetch("registration_forms").first.fetch("in_use")).to be(true)
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join).to include(
      I18n.t("event_registration.form_in_use"),
    )
    sign_in(admin)
    freeze_time Time.utc(2030, 1, 8, 18)
    get "#{url}/#{form.id}/edit.json"
    expect(response.parsed_body.fetch("in_use")).to be(true)
    expect(response.parsed_body.fetch("has_linked_events")).to be(true)
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:unprocessable_entity)
    freeze_time Time.utc(2030, 1, 9)
    get "#{url}/#{form.id}/edit.json"
    expect(response.parsed_body).to include("in_use" => false, "has_linked_events" => true)
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:no_content)
  end

  it "protects recurring series between dates and through the end of their final occurrence" do
    start = Time.utc(2030, 1, 7, 12)
    freeze_time start + 3.days
    form = DiscourseEvents::Events::RegistrationForm.create!(definition:)
    series =
      Fabricate(
        :event,
        registration_form_id: form.id,
        registration_form: definition,
        original_starts_at: start,
        original_ends_at: start + 2.hours,
        recurrence: "every_week",
        timezone: "UTC",
      )
    sign_in(admin)
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:unprocessable_entity)
    series.update!(recurrence_until: start + 1.week + 30.minutes)
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:unprocessable_entity)
    freeze_time start + 1.week + 1.hour
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:unprocessable_entity)
    series.update!(recurrence_until: start + 10.days)
    freeze_time start + 1.week + 2.hours
    delete "#{url}/#{form.id}.json"
    expect(response).to have_http_status(:no_content)
  end

  it "denies access to the library to guests and regular members" do
    get "#{url}.json"
    expect(response).to have_http_status(:forbidden)
    sign_in(Fabricate(:user))
    get "#{url}.json"
    expect(response).to have_http_status(:forbidden)
  end
end
