# frozen_string_literal: true

describe "Admin User Fields" do
  fab!(:current_user, :admin)

  before { sign_in(current_user) }

  let(:user_fields_page) { PageObjects::Pages::AdminUserFields.new }
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  it "correctly saves user fields" do
    user_fields_page.visit
    expect(page_header).to RSpecPredicates.be_visible
    user_fields_page.add_field(name: "Occupation", description: "What you do for work")

    expect(user_fields_page).to have_user_field("Occupation")

    browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(user_fields_page).to have_user_field("Occupation")
  end

  it "displays an error when missing required fields" do
    user_fields_page.visit

    user_fields_page.add_field(name: "Occupation", description: "")

    expect(user_fields_page.form.field("description")).to have_errors("Required")
  end

  it "makes sure new required fields are editable after signup" do
    user_fields_page.visit
    user_fields_page.click_add_field

    expect(page_header).to RSpecPredicates.be_hidden

    form = browser_root.locator(".user-field").filter(visible: true)
    editable_label = I18n.t("admin_js.admin.user_fields.editable.title")

    user_fields_page.choose_requirement("for_all_users")

    expect(
      form
        .locator("input, textarea, select")
        .and(
          form.locator(
            "[id=#{editable_label.to_s.to_json}], [name=#{editable_label.to_s.to_json}]",
          ).or(form.get_by_label(editable_label, exact: true)),
        )
        .and(form.locator(":disabled")),
    ).to be_checked(checked: true)

    user_fields_page.choose_requirement("optional")

    expect(
      form.locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)").and(
        form.locator(
          "[id=#{editable_label.to_s.to_json}], [name=#{editable_label.to_s.to_json}]",
        ).or(form.get_by_label(editable_label, exact: true)),
      ),
    ).to be_checked(checked: true)
  end

  it "makes sure fields are available on signup when they have to" do
    user_fields_page.visit
    user_fields_page.click_add_field

    expect(page_header).to RSpecPredicates.be_hidden

    form = browser_root.locator(".user-field").filter(visible: true)
    show_on_signup_label = I18n.t("admin_js.admin.user_fields.show_on_signup.title")

    user_fields_page.choose_requirement("for_all_users")

    expect(
      form
        .locator("input, textarea, select")
        .and(
          form.locator(
            "[id=#{show_on_signup_label.to_s.to_json}], [name=#{show_on_signup_label.to_s.to_json}]",
          ).or(form.get_by_label(show_on_signup_label, exact: true)),
        )
        .and(form.locator(":disabled")),
    ).to be_checked(checked: true)

    user_fields_page.choose_requirement("on_signup")

    expect(
      form
        .locator("input, textarea, select")
        .and(
          form.locator(
            "[id=#{show_on_signup_label.to_s.to_json}], [name=#{show_on_signup_label.to_s.to_json}]",
          ).or(form.get_by_label(show_on_signup_label, exact: true)),
        )
        .and(form.locator(":disabled")),
    ).to be_checked(checked: true)

    user_fields_page.choose_requirement("optional")

    expect(
      form.locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)").and(
        form.locator(
          "[id=#{show_on_signup_label.to_s.to_json}], [name=#{show_on_signup_label.to_s.to_json}]",
        ).or(form.get_by_label(show_on_signup_label, exact: true)),
      ),
    ).to be_checked(checked: true)

    user_fields_page.unselect_preference("editable")

    expect(
      form
        .locator("input, textarea, select")
        .and(
          form.locator(
            "[id=#{show_on_signup_label.to_s.to_json}], [name=#{show_on_signup_label.to_s.to_json}]",
          ).or(form.get_by_label(show_on_signup_label, exact: true)),
        )
        .and(form.locator(":disabled")),
    ).to be_checked(checked: true)
  end

  it "requires confirmation when applying required fields retroactively" do
    user_fields_page.visit
    user_fields_page.add_field(
      name: "Favourite Pokémon",
      description: "Hint: It's Mudkip",
      save: false,
    )
    user_fields_page.choose_requirement("for_all_users")
    user_fields_page.form.submit

    expect(browser_content).to contain_text(
      browser_text_pattern(I18n.t("admin_js.admin.user_fields.requirement.confirmation")),
      useInnerText: true,
    )
  end

  context "when editing an existing user field" do
    fab!(:user_field) { Fabricate(:user_field, requirement: "for_all_users") }

    it "does not require confirmation if the field already applies to all users" do
      user_fields_page.visit
      user_fields_page.click_edit

      form = browser_root.locator(".user-field").filter(visible: true)

      form.locator(".user-field-name").filter(visible: true).fill("Favourite Transformer")

      expect(page_header).to RSpecPredicates.be_hidden

      form.locator(".btn-primary").filter(visible: true).click

      expect(browser_content).not_to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.user_fields.requirement.confirmation")),
        useInnerText: true,
      )
    end
  end

  context "when enable_new_reordering_controls is enabled" do
    fab!(:field1) { Fabricate(:user_field, name: "Favourite colour") }
    fab!(:field2) { Fabricate(:user_field, name: "Home town") }

    before { SiteSetting.enable_new_reordering_controls = true }

    it "keeps each row's controls anchored to its own row on mobile", mobile: true do
      user_fields_page.visit

      expect(browser_root.locator(".admin-user_field-item").filter(visible: true)).to have_count(2)

      escaped = browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          Array.from(document.querySelectorAll(".d-table__cell.--controls")).filter(
            (cell) => cell.offsetParent !== cell.closest("tr")
          ).length
        JS

      expect(escaped).to eq(0)
    end

    it "sizes the drag handle column to the handle" do
      user_fields_page.visit

      expect(browser_root.locator(".admin-user_field-item").filter(visible: true)).to have_count(2)

      width = browser_page.evaluate("function(arguments) { return #{<<~JS} }", arg: [])
          Math.round(
            document
              .querySelector(".d-reorderable-list__handle")
              .closest("td")
              .getBoundingClientRect().width
          )
        JS

      expect(width).to be < 60
    end
  end
end
