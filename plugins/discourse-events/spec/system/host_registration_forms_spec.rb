# frozen_string_literal: true

describe "Host registration form creation" do
  fab!(:admin)
  fab!(:host) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:hosts, :group) { Fabricate(:group).tap { |group| group.add(host) } }

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = hosts.id.to_s
  end

  it "lets a member of an event creation group create and select a form in the event draft" do
    sign_in(host)
    create_form_from_dropdown("/discourse-post-event/registration-forms/new")
  end

  it "offers account-only registration without a Preview action in the event editor" do
    sign_in(host)
    composer = PageObjects::Components::Composer.new
    visit "/new-topic?category=#{Fabricate(:category).slug}"
    composer.fill_title("Weekend workshop")
    composer.fill_content(%([event start="2030-06-01 10:00" status="public"]\n[/event]))
    picker = I18n.t("js.event_registration.select")
    expect(composer.preview).to have_select(picker, selected: "Do not track registration")
    composer.preview.select("Username/Email only", from: picker)
    expect(composer).to have_value(/registrationForm=account/)
    expect(composer.preview).to have_select(picker, selected: "Username/Email only")
    expect(composer.preview).to have_no_button("Preview")
    composer.preview.select("Do not track registration", from: picker)
    expect(page).to have_no_field(class: "d-editor-input", with: /registrationForm/)
  end

  it "lists the built-in form as read-only and links its usage to the filtered submissions" do
    form = DiscourseEvents::Events::RegistrationForm.account_only_definition
    event = Fabricate(:event, registration_form: form)
    sign_in(admin)
    visit "/admin/plugins/discourse-events/registration-forms"
    row = find("tbody tr", text: "Username/Email only")
    expect(row).to have_text("System")
    expect(row).to have_no_link("Username/Email only")
    edit = row.find_button("Edit", disabled: true)
    expect(row).to have_no_button("Delete")
    edit.hover
    expect(page).to have_css('[role="tooltip"]', text: "Built-in default")
    usage = row.find_link("1")
    usage.hover
    expect(page).to have_no_css('[role="tooltip"]')
    usage.send_keys(:tab)
    expect(page).to have_css('[role="tooltip"]', text: "Built-in default")
    page.send_keys(%i[shift tab])
    expect(page).to have_no_css('[role="tooltip"]')
    usage.click
    expect(page).to have_current_path(%r{/discourse-events/submissions\?form_id=account})
    within(".d-filter-controls") { expect(page).to have_select(selected: "Username/Email only") }
    expect(page).to have_link(event.post.topic.title)
  end

  it "selects a form created through the admin editor in the event draft" do
    sign_in(admin)
    create_form_from_dropdown("/admin/plugins/discourse-events/registration-forms/new")
  end

  it "lets an admin delete an unused custom form from the submissions filter" do
    title = "Workshop signup"
    DiscourseEvents::Events::RegistrationForm.create!(
      definition: {
        title:,
        fields: [{ id: "team", type: "text", label: "Team", required: false }],
      },
    )
    sign_in(admin)
    path = "/admin/plugins/discourse-events/submissions"
    visit "#{path}?form_id=account"
    expect(page).to have_text("No events use this form.")
    expect(page).to have_no_button("Delete form")

    find(".d-filter-controls__dropdown").select(title)
    search = find('input[placeholder="Search by event or form name"]')
    search.fill_in(with: "missing")
    expect(page).to have_text("No events match your search.")
    expect(page).to have_no_button("Delete form")
    search.fill_in(with: "")

    within(".admin-config-area-empty-list") { click_button("Delete form") }
    dialog = PageObjects::Components::Dialog.new
    expect(dialog).to have_content("Delete “#{title}” from the library?")
    dialog.click_no
    expect(page).to have_select(selected: title)
    click_button("Delete form")
    dialog.click_danger
    expect(page).to have_current_path(path)
    expect(page).to have_select(
      selected: "All registration forms",
      options: ["All registration forms", "Username/Email only"],
    )
  end

  it "lets a host edit and remove their own shared forms from Manage forms" do
    sign_in(host)
    definition = {
      title: "My workshop",
      fields: [{ id: "team", type: "text", label: "Team", required: false }],
    }
    forms = DiscourseEvents::Events::RegistrationForm
    mine = forms.create!(created_by: host, definition:)
    forms.create!(created_by: admin, definition: definition.merge(title: "Site signup"))
    composer = PageObjects::Components::Composer.new
    category = Fabricate(:category)
    visit "/new-topic?category=#{category.slug}"
    composer.fill_title("Weekend workshop")
    composer.fill_content(%([event start="2030-06-01 10:00" status="public"]\n[/event]))
    picker = I18n.t("js.event_registration.select")
    expect(composer.preview).to have_select(picker, with_options: ["My workshop", "Site signup"])
    tab = window_opened_by { composer.preview.select("Manage my forms", from: picker) }
    within_window(tab) do
      library_path = "/discourse-post-event/registration-forms/mine"
      expect(page).to have_current_path(library_path)
      expect(page).to have_no_link("Site signup")
      expect(page).to have_css("a[data-user-card='#{host.username}'] img.avatar")
      click_link("My workshop")
      expect(page).to have_current_path("/discourse-post-event/registration-forms/#{mine.id}/edit")
      within(".d-floating-control-bar") do
        delete_button = find_button("Delete")
        expect(delete_button["aria-label"]).to eq("Delete My workshop")
        expect(
          delete_button.evaluate_script(
            "Math.abs(this.getBoundingClientRect().right - this.parentElement.getBoundingClientRect().right)",
          ),
        ).to be < 2
        delete_button.click
      end
      dialog = PageObjects::Components::Dialog.new
      expect(dialog).to have_content("Delete “My workshop” from the library?")
      dialog.click_no
      find('[name="title"]').fill_in(with: "Updated workshop")
      find('.form-definition-editor [type="submit"]').click
      expect(page).to have_current_path(library_path)
      within(".d-table__cell-actions") do
        expect(page).to have_button("Edit")
        delete = find_button("Delete Updated workshop")
        expect(delete[:class].split).to include("btn-default", "btn-icon")
        expect(delete).to have_css(".d-icon-trash-can")
        delete.click
      end
      expect(dialog).to have_content(
        "Existing events keep their registration forms and submissions.",
      )
      dialog.click_danger
      expect(page).to have_current_path(library_path)
      expect(page).to have_text("You haven’t created any registration forms yet.")
    end
    tab.close
    page.execute_script("window.dispatchEvent(new Event('focus'))")
    expect(composer.preview).to have_select(
      picker,
      options: [
        "Do not track registration",
        "Username/Email only",
        "Site signup",
        "Create new",
        "Manage my forms",
      ],
    )
  end

  def create_form_from_dropdown(editor_path)
    composer = PageObjects::Components::Composer.new
    category = Fabricate(:category)
    visit "/new-topic?category=#{category.slug}"
    composer.fill_title("Weekend workshop")
    composer.fill_content(%([event start="2030-06-01 10:00" status="public"]\n[/event]))

    label = I18n.t("js.event_registration.select")
    management_label = editor_path.start_with?("/admin/") ? "Manage forms" : "Manage my forms"
    expect(composer.preview).to have_select(label, with_options: [management_label])
    create = I18n.t("js.event_registration.create")
    title = "Weekend workshop signup"
    form_tab = window_opened_by { composer.preview.select(create, from: label) }
    within_window(form_tab) do
      expect(page).to have_current_path(editor_path, ignore_query: true)
      find('[name="title"]').fill_in(with: title)
      find('[name="fields.0.label"]').fill_in(with: "Team name")
      # The editor tab closes on save, before Capybara can wait for it to settle.
      find('.form-definition-editor [type="submit"]').native.click
    end
    expect(composer.preview).to have_select(label, selected: title)
    expect(composer).to have_value(/registrationFormId=/)
    try_until_success { expect(form_tab).to be_closed }

    cancelled_tab = window_opened_by { composer.preview.select(create, from: label) }
    cancelled_tab.close
    expect(composer.preview).to have_select(label, selected: title)
    composer.preview.click_button(I18n.t("js.event_registration.preview"))
    expect(page).to have_css(".event-registration label", text: "Team name")
  end
end
