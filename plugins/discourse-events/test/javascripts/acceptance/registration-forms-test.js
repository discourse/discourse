import {
  click,
  currentURL,
  fillIn,
  find,
  select,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Events | Admin registration forms", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    discourse_events_enabled: true,
    discourse_post_event_enabled: true,
  });

  const base = "/admin/plugins/discourse-events";
  const library = base + "/registration-forms";
  const api = "/discourse-post-event/registration-forms";

  needs.pretender((server) => {
    server.get(base + ".json", () =>
      response({
        id: "discourse-events",
        name: "discourse-events",
        humanized_name: "Events",
        enabled: true,
        has_settings: true,
        admin_route: { use_new_show_route: true, location: "discourse-events" },
      })
    );
  });

  test("previews unfinished fields and choices while editing a new form", async function (assert) {
    pretender.get("/u/eviltrout/emails.json", () =>
      response({ email: "previewer@example.com" })
    );
    await visit(library + "/new");
    const preview = ".form-definition-editor__preview";
    const close = ".event-registration .modal-close";
    const label = '[name="fields.0.label"]';
    const choice = '[name="fields.0.choices.1.label"]';

    await click(preview);
    assert
      .dom(".event-registration")
      .includesText(
        i18n("form_definition.untitled"),
        "the starter field has a preview label"
      );
    await click(close);
    assert.dom(label).hasValue("", "the draft label is still empty");

    await formKit().field("fields.0.type").select("dropdown");
    await fillIn(label, "Lunch");
    await fillIn('[name="fields.0.choices.0.label"]', "Vegetarian");
    await fillIn(choice, "  ");
    await click(preview);
    assert
      .dom(".event-registration")
      .includesText("Lunch", "the preview uses the authored field label");
    assert
      .dom(".event-registration select option:nth-last-child(2)")
      .hasText("Vegetarian", "the preview uses the authored choice label");
    assert
      .dom(".event-registration select option:last-child")
      .hasText(
        i18n("form_definition.choice_number", { number: 2 }),
        "the unnamed choice is numbered"
      );
    await click(close);
    assert
      .dom(choice)
      .hasValue("  ", "the preview leaves the draft choice as entered");
  });

  test("creates, previews and edits a registration form from the plugin tab", async function (assert) {
    const description = "Template for the conference organizing team";
    const fieldDescription = "Select this if you need a parking pass.";
    let saved;
    pretender.get("/u/eviltrout/emails.json", () =>
      response({ email: "previewer@example.com" })
    );
    pretender.get(api + ".json", () =>
      response({
        registration_forms: saved
          ? [
              {
                id: 2,
                title: saved.title,
                description: saved.description,
                field_count: saved.fields.length,
                event_count: 0,
              },
            ]
          : [],
      })
    );
    pretender.post(api + ".json", (request) => {
      saved = JSON.parse(request.requestBody).definition;
      return response(201, { id: 2, definition: saved });
    });
    pretender.get(api + "/2/edit.json", () =>
      response({ id: 2, definition: saved, has_linked_events: true })
    );
    pretender.put(api + "/2.json", (request) => {
      saved = JSON.parse(request.requestBody).definition;
      return response({ id: 2, definition: saved });
    });
    await visit(library);
    assert
      .dom('a[href="' + library + '"]')
      .exists("the plugin navigation links to the library");
    await click(".d-page-subheader .btn-primary");
    assert.strictEqual(currentURL(), library + "/new");
    const versionNotice = i18n(
      "event_registration.library.existing_events_keep_version"
    );
    assert
      .dom(".event-registration-form-editor")
      .doesNotIncludeText(versionNotice);
    assert
      .dom('[data-name="title"] label')
      .hasText("Form title (private)", "the title is marked private");
    assert
      .dom('[data-name="description"] label')
      .hasText(
        "Description (private, optional)",
        "the description is marked private and optional"
      );
    assert
      .dom('[data-name="title"] label .form-kit__container-optional')
      .hasText("(private)", "only the title qualifier uses the optional style");
    assert
      .dom('[data-name="description"] label .form-kit__container-optional')
      .hasText(
        "(private, optional)",
        "both description qualifiers share the optional style"
      );
    const footer = ".form-definition-editor .d-floating-control-bar";
    const saveButton = footer + ' [type="submit"]';
    assert.strictEqual(
      find(footer).offsetWidth,
      find(".event-registration-form-editor").offsetWidth,
      "the save bar spans the full editor card"
    );
    assert.dom(saveButton).hasText(i18n("save"));
    await click(saveButton);
    assert.dom(".form-kit__errors-summary").exists();
    await fillIn(
      '.form-definition-editor [data-name="title"] input',
      "Conference signup"
    );
    const descriptionField =
      '.form-definition-editor [data-name="description"] input';
    await fillIn(descriptionField, description);
    assert
      .dom(".form-definition-editor__question")
      .exists({ count: 1 }, "new forms start with one field");
    assert.dom('[name="fields.0.type"]').hasValue("text");
    await formKit().field("fields.0.type").select("display_text");
    await fillIn(
      '[name="fields.0.content"]',
      "Pick up your badge at the door."
    );
    await click(saveButton);
    assert
      .dom(".form-kit__errors-summary")
      .includesText(i18n("event_registration.library.needs_answer_field"));
    assert.strictEqual(saved, undefined);
    await formKit().field("fields.0.type").select("text");
    await click(".form-definition-editor__field-menu");
    assert
      .dom('[data-field-action="remove"]')
      .isDisabled("the last field cannot be deleted");
    await click(".form-definition-editor__field-menu");
    await fillIn('[name="fields.0.label"]', "Parking pass");
    const attributesMenu = ".form-definition-editor__attributes";
    const descriptionOption = '[data-field-attribute="description"]';
    const fieldDescriptionInput = '[name="fields.0.description"]';
    assert.dom(fieldDescriptionInput).doesNotExist();
    await click(attributesMenu);
    await click(descriptionOption);
    await fillIn(fieldDescriptionInput, fieldDescription);
    await formKit().field("fields.0.type").select("checkbox");
    await click(footer + " .form-definition-editor__preview");
    assert.dom(".event-registration h1").hasText("Event registration");
    assert
      .dom(".event-registration")
      .doesNotIncludeText("Conference signup")
      .doesNotIncludeText(description);
    assert.dom(".event-registration label").hasText("Account email");
    const checkbox = '.event-registration input[type="checkbox"]';
    assert.dom(checkbox).hasAttribute("aria-describedby");
    assert
      .dom(
        document.getElementById(find(checkbox).getAttribute("aria-describedby"))
      )
      .hasText(fieldDescription);
    assert
      .dom('.event-registration input[type="email"]')
      .hasValue("previewer@example.com")
      .hasAttribute("readonly");
    await click(".event-registration .modal-close");
    await click(saveButton);
    assert.strictEqual(saved.fields[0].description, fieldDescription);
    assert.strictEqual(currentURL(), library);
    assert.dom(".d-table__overview-about").hasText(description);
    const editButton = ".d-table tbody tr td:last-child.--controls button";
    assert
      .dom(editButton)
      .hasText("Edit")
      .hasAttribute("aria-label", "Edit Conference signup");
    assert
      .dom(
        '.d-table__cell-actions button[aria-label="Delete Conference signup"]'
      )
      .isEnabled();
    await click(editButton);
    assert.strictEqual(currentURL(), library + "/2/edit");
    assert.dom(".event-registration-form-editor").includesText(versionNotice);
    assert.strictEqual(
      find(".form-definition-editor__question").offsetWidth,
      find(descriptionField).offsetWidth,
      "a saved field card spans the same width as the form description"
    );
    assert.dom(footer + " .form-definition-editor__preview").hasText("Preview");
    assert.dom(descriptionField).hasValue(description);
    assert.dom(fieldDescriptionInput).hasValue(fieldDescription);
    await click(attributesMenu);
    assert.dom(descriptionOption).hasAttribute("aria-pressed", "true");
    await click(descriptionOption);
    assert.dom(fieldDescriptionInput).doesNotExist();
    await fillIn(descriptionField, "");
    await fillIn(
      '.form-definition-editor [data-name="title"] input',
      "Conference RSVP"
    );
    await click(saveButton);
    assert.false(Object.hasOwn(saved.fields[0], "description"));
    assert.dom('a[href="' + library + '/2/edit"]').hasText("Conference RSVP");
    assert.dom(".d-table__overview-about").doesNotExist();
  });

  test("filters submissions by form from the library and the dropdown", async function (assert) {
    const forms = [
      {
        id: 5,
        title: "Workshop signup",
        field_count: 3,
        event_count: 51,
        in_use: true,
      },
      { id: 6, title: "Unused", field_count: 1, event_count: 0 },
    ];
    pretender.get(api + ".json", (request) => {
      return response({
        registration_forms:
          request.queryParams.include_usage === "true"
            ? forms
            : forms.map(({ id, title }) => ({ id, title })),
      });
    });
    pretender.get(base + "/submissions.json", (request) => {
      const { form_id, page } = request.queryParams;
      if (form_id === "6") {
        return response({ events: [], previous_page: null, next_page: null });
      }
      const filtered = form_id === "5";
      const secondPage = page === "2";
      return response({
        events: [
          {
            id: 9,
            url: "/t/workshop/9",
            title: filtered
              ? secondPage
                ? "Final workshop"
                : "First workshop"
              : "All workshops",
            submission_count: 0,
          },
        ],
        previous_page: secondPage ? 1 : null,
        next_page: filtered && !secondPage ? 2 : null,
      });
    });
    await visit(library);
    const first = ".d-table tbody tr:first-child";
    assert
      .dom(first + ' button[aria-label="Delete Workshop signup"]')
      .isDisabled()
      .hasAttribute("title", i18n("event_registration.library.delete_in_use"));
    assert.dom(".d-table thead th").exists({ count: 4 });
    assert
      .dom(".d-table thead th:nth-child(2)")
      .hasText(i18n("event_registration.library.events"));
    const eventsLink = first + " td:nth-child(2) a";
    assert
      .dom(eventsLink)
      .hasText("51")
      .hasAttribute("aria-label", "View 51 events using Workshop signup");
    const unused = ".d-table tbody tr:last-child td:nth-child(2)";
    assert.dom(unused).includesText("0");
    assert.dom(unused + " a").doesNotExist();
    await click(eventsLink);
    const filter = ".d-filter-controls__dropdown";
    assert
      .dom(filter)
      .hasValue("5")
      .hasAttribute("aria-label", "All registration forms");
    assert.dom(filter + " option:checked").hasText("Workshop signup");
    assert.dom('tbody a[href="/t/workshop/9"]').hasText("First workshop");
    await click('a[href*="page=2"]');
    assert.dom("tbody tr").includesText("Final workshop");
    assert.dom(filter).hasValue("5");
    await select(filter, "6");
    assert.strictEqual(currentURL(), base + "/submissions?form_id=6");
    assert
      .dom(".admin-config-area-empty-list")
      .includesText("No events use this form.");
    await select(filter, "all");
    assert.strictEqual(currentURL(), base + "/submissions");
    assert.dom("tbody tr").includesText("All workshops");
    await select(filter, "5");
    assert.dom("tbody tr").includesText("First workshop");
  });
});
