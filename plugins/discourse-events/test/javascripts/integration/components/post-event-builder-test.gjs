import { getOwner } from "@ember/owner";
import { click, fillIn, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import PostEventBuilder from "discourse/plugins/discourse-events/discourse/components/modal/post-event-builder";
import DiscoursePostEventEvent from "discourse/plugins/discourse-events/discourse/models/discourse-post-event-event";

const registrationField = '[data-name="registrationForm"]';

function eventWith(attrs = {}) {
  return DiscoursePostEventEvent.create({
    name: "My event",
    starts_at: "2022-07-01T10:00:00Z",
    ends_at: "2022-07-01T11:00:00Z",
    timezone: "UTC",
    status: "public",
    reminders: [],
    raw_invitees: [],
    custom_fields: {},
    ...attrs,
  });
}

async function renderAdvanced(event, modelOverrides = {}) {
  const model = {
    event,
    initialScreen: "advanced",
    onUpdate: () => {},
    toolbarEvent: {},
    ...modelOverrides,
  };
  const closeModal = () => {};

  await render(
    <template>
      <PostEventBuilder
        @closeModal={{closeModal}}
        @inline={{true}}
        @model={{model}}
      />
    </template>
  );
}

module("Integration | Component | Modal | PostEventBuilder", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    this.user = store.createRecord("user", {
      username: "tom",
      id: 1,
      admin: true,
    });

    getOwner(this).unregister("service:current-user");
    getOwner(this).register("service:current-user", this.user, {
      instantiate: false,
    });
  });

  test("hides form creation and management from members outside the event creation groups", async function (assert) {
    this.user.setProperties({
      admin: false,
      can_create_discourse_post_event: false,
    });
    this.siteSettings.discourse_post_event_enabled = true;
    await renderAdvanced(eventWith());
    const control = find(registrationField + " select");
    assert.dom(registrationField).hasClass("--full");
    assert.dom(control).hasClass("form-kit__control-select");
    assert
      .dom(registrationField + " label")
      .includesText("Registration form")
      .hasAttribute("for", control.id);
    assert.dom(".event-registration-picker__sizer").doesNotExist();
    assert.dom(registrationField + ' option[value="create"]').doesNotExist();
    assert.dom(registrationField + ' option[value="manage"]').doesNotExist();
  });

  test("offers Create new and Manage my forms to members who can create events", async function (assert) {
    this.user.setProperties({
      admin: false,
      can_create_discourse_post_event: true,
    });
    this.siteSettings.discourse_post_event_enabled = true;
    await renderAdvanced(eventWith());
    assert
      .dom(registrationField + ' option[value="create"]')
      .hasText("Create new");
    assert
      .dom(registrationField + ' option[value="manage"]')
      .hasText("Manage my forms");
  });

  test("selects a form created in another tab and previews it without leaving the event", async function (assert) {
    const event = eventWith();
    let forms = [];
    pretender.get("/discourse-post-event/registration-forms.json", () =>
      response({ registration_forms: forms })
    );
    pretender.get("/discourse-post-event/registration-forms/3.json", () =>
      response({
        id: 3,
        definition: {
          title: "Workshop signup",
          fields: [
            { id: "team", label: "Team", required: false, type: "text" },
          ],
        },
      })
    );
    await renderAdvanced(event);
    await fillIn('[data-name="location"] input', "Room 4");
    assert.dom(registrationField + ' option[value="create"]').exists();
    forms = [{ id: 3, title: "Workshop signup" }];
    window.dispatchEvent(new Event("focus"));
    await settled();
    await formKit().field("registrationForm").select("3");
    assert
      .dom(registrationField + " select")
      .hasAttribute(
        "aria-describedby",
        find(registrationField + " .form-kit__container-help-text").id
      );
    assert.dom(registrationField + " .btn-link").hasText("Preview");
    await click(registrationField + " .btn-link");
    assert.dom(".event-registration h1").hasText("Event registration");
    assert
      .dom('.event-registration [data-name="team"] label')
      .includesText("Team");
    await click(".event-registration .modal-close");
    assert.dom(registrationField + " select").hasValue("3");
    assert.dom('[data-name="location"] input').hasValue("Room 4");
    assert.strictEqual(event.registrationFormId, undefined);
    await click(".btn-primary");
    assert.strictEqual(event.registrationFormId, 3);
  });

  test("keeps an event’s removed form selected until the host chooses another registration option", async function (assert) {
    pretender.get("/discourse-post-event/registration-forms.json", () =>
      response({ registration_forms: [] })
    );
    const event = eventWith({
      registration_form_id: 7,
      registration_form: { title: "Original signup", fields: [] },
    });
    await renderAdvanced(event);
    const control = registrationField + " select";
    assert.dom(control).hasValue("7");
    assert
      .dom(control + ' option[value="7"]')
      .isDisabled()
      .hasText("Original signup");
    await formKit().field("registrationForm").select("account");
    assert.dom(control).hasValue("account");
    assert.dom(registrationField + " .btn-link").doesNotExist();
    await click(".btn-primary");
    assert.strictEqual(event.registrationForm.builtin, "account");
    assert.strictEqual(event.registrationFormId, null);
  });

  test("reminder edits persist in advanced settings and the saved event", async function (assert) {
    const event = eventWith({
      reminders: [
        { type: "notification", value: 15, unit: "minutes", period: "before" },
        { type: "notification", value: 30, unit: "minutes", period: "before" },
      ],
    });
    let savedEvent;
    await renderAdvanced(event, {
      onUpdate: (startsAt, endsAt, updatedEvent) => {
        savedEvent = updatedEvent;
      },
    });

    await fillIn('[data-name="reminders.1.value"] input', "2");
    assert
      .dom('[data-name="reminders.1.value"] input')
      .hasValue("2", "the number does not reset");

    await formKit().field("reminders.1.unit").select("hours");
    assert
      .dom('[data-name="reminders.1.unit"] select')
      .hasValue("hours", "the unit does not reset");

    await fillIn('[data-name="location"] input', "Sydney");
    assert
      .dom('[data-name="reminders.1.value"] input')
      .hasValue("2", "the number survives another field edit");
    assert
      .dom('[data-name="reminders.1.unit"] select')
      .hasValue("hours", "the unit survives another field edit");

    await click(".btn-primary");
    assert.strictEqual(
      Number(savedEvent.reminders[1].value),
      2,
      "saves the edited number"
    );
    assert.strictEqual(
      savedEvent.reminders[1].unit,
      "hours",
      "saves the edited unit"
    );
    assert.strictEqual(
      Number(savedEvent.reminders[0].value),
      15,
      "leaves the other reminder unchanged"
    );
    assert.strictEqual(
      savedEvent.reminders[0].unit,
      "minutes",
      "leaves the other unit unchanged"
    );
  });

  test("advanced screen renders an existing image upload as its URL", async function (assert) {
    const event = eventWith({
      image_upload: {
        url: "/uploads/default/original/1X/test-event-image.png",
        short_url: "upload://test-event-image",
      },
    });

    await renderAdvanced(event);

    assert
      .dom(`[data-name="imageUpload"] .file-uploader`)
      .hasClass("has-image", "the image control shows the uploaded image");
    assert
      .dom(`[data-name="imageUpload"] .file-uploader__preview`)
      .hasAttribute(
        "style",
        /url\(\/uploads\/default\/original\/1X\/test-event-image\.png\)/,
        "renders the upload url, not the raw object"
      );
  });

  test("advanced screen renders a custom field whose name contains a dash", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields = "field-aa";

    const event = eventWith();

    await renderAdvanced(event);

    assert
      .dom(`[data-name="customFields.field_aa"] input`)
      .exists("renders the dashed custom field without crashing");
  });

  test("clears livestream when the location stops being a URL", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = eventWith({
      location: "https://zoom.us/j/123456789",
      livestream: true,
    });

    await renderAdvanced(event);

    assert
      .dom(`[data-name="livestream"]`)
      .exists("the livestream field shows while the location is a URL");

    await fillIn(`[data-name="location"] input`, "Room 5");

    assert
      .dom(`[data-name="livestream"]`)
      .doesNotExist("the livestream field is hidden for a non-URL location");
    assert.false(
      event.livestream,
      "livestream is reset so it is not submitted for a non-URL location"
    );
  });

  test("typed custom field keeps its value when the location is edited", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields = "test1";

    const event = eventWith();

    let updatedEvent = null;
    await renderAdvanced(event, {
      onUpdate: (startsAt, endsAt, savedEvent) => {
        updatedEvent = savedEvent;
      },
    });

    await fillIn(`[data-name="customFields.test1"] input`, "hello");
    await fillIn(`[data-name="location"] input`, "Sydney");

    assert
      .dom(`[data-name="customFields.test1"] input`)
      .hasValue("hello", "the custom field is not visually cleared");

    await click(".btn-primary");
    assert.strictEqual(
      updatedEvent.customFields.test1,
      "hello",
      "the custom field value is part of the saved event"
    );
  });

  test("editing a local-time event preserves its wall-clock time", async function (assert) {
    const event = eventWith({
      starts_at: "2026-09-30T20:15:00",
      ends_at: "2026-09-30T22:15:00",
      timezone: "Europe/Madrid",
      show_local_time: true,
    });

    let savedDates;
    await renderAdvanced(event, {
      onUpdate: (startsAt, endsAt) => {
        savedDates = { startsAt, endsAt };
      },
    });

    await fillIn(`[data-name="description"] textarea`, "Updated description");
    await click(".btn-primary");

    assert.strictEqual(
      savedDates.startsAt.format("YYYY-MM-DD HH:mm Z"),
      "2026-09-30 20:15 +02:00",
      "the start remains anchored to the event timezone"
    );
    assert.strictEqual(
      savedDates.endsAt.format("YYYY-MM-DD HH:mm Z"),
      "2026-09-30 22:15 +02:00",
      "the end remains anchored to the event timezone"
    );
  });

  test("typed custom field survives a compact-screen edit in between", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields = "test1";

    const event = eventWith({ custom_fields: { test1: "seeded" } });

    let updatedEvent = null;
    await renderAdvanced(event, {
      initialScreen: "compact",
      onUpdate: (startsAt, endsAt, savedEvent) => {
        updatedEvent = savedEvent;
      },
    });

    await click(".advanced-mode-btn");
    await fillIn(`[data-name="customFields.test1"] input`, "typed");

    await click(".advanced-mode-btn");
    await fillIn(".composer-event__location-input", "Sydney");

    await click(".advanced-mode-btn");
    assert
      .dom(`[data-name="customFields.test1"] input`)
      .hasValue("typed", "the advanced screen shows the latest value");

    await click(".btn-primary");
    assert.strictEqual(
      updatedEvent.customFields.test1,
      "typed",
      "the compact edit does not revive the stale value"
    );
  });

  test("advanced screen exposes an existing url so it can be edited", async function (assert) {
    const event = eventWith({ url: "https://meet.example.com/legacy" });
    await renderAdvanced(event);

    assert
      .dom(`[data-name="url"] input`)
      .hasValue(
        "https://meet.example.com/legacy",
        "a defined url is always reachable, never a hidden field"
      );
    assert
      .dom(".add-event-url")
      .doesNotExist("no add affordance while the field is already shown");

    await fillIn(`[data-name="url"] input`, "");

    assert.strictEqual(
      event.url,
      null,
      "clearing the field clears the event url, so buildParams drops it"
    );
  });

  test("advanced screen offers a recording field once a livestream has ended", async function (assert) {
    const event = eventWith({ livestream: true });
    await renderAdvanced(event);

    await fillIn(`[data-name="recordingUrl"] input`, "https://youtu.be/abc");

    assert.strictEqual(event.recordingUrl, "https://youtu.be/abc");
  });

  test("advanced screen hides the recording field before a livestream ends", async function (assert) {
    const event = eventWith({
      livestream: true,
      starts_at: "2099-07-01T10:00:00Z",
      ends_at: "2099-07-01T11:00:00Z",
    });
    await renderAdvanced(event);

    assert.dom(`[data-name="recordingUrl"]`).doesNotExist();
  });

  test("offers livestream when the url field carries the livestream link", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = eventWith({ url: "https://zoom.us/j/123456789" });
    await renderAdvanced(event);

    assert
      .dom(`[data-name="livestream"]`)
      .exists("a livestream link is recognized in either field");

    await fillIn(`[data-name="url"] input`, "https://example.com/tickets");

    assert
      .dom(`[data-name="livestream"]`)
      .doesNotExist("a plain link offers nothing to embed");
    assert.false(
      event.livestream,
      "livestream is reset so it is not submitted for a non-livestream url"
    );
  });

  test("keeps the livestream flag when only the companion url changes", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = eventWith({
      location: "https://zoom.us/j/123456789",
      url: "https://example.com/tickets",
      livestream: true,
    });
    await renderAdvanced(event);

    await fillIn(`[data-name="url"] input`, "https://example.com/register");

    assert
      .dom(`[data-name="livestream"]`)
      .exists("the location still carries the stream");
    assert.true(event.livestream, "the flag survives a companion url edit");
  });

  test("ignores a whitespace-only location when the url carries the stream", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = eventWith({
      url: "https://zoom.us/j/123456789",
      livestream: true,
    });
    await renderAdvanced(event);

    await fillIn(`[data-name="location"] input`, " ");

    assert
      .dom(`[data-name="livestream"]`)
      .exists("a blank location does not shadow the url");
    assert.true(
      event.livestream,
      "the flag matches what the save path would keep"
    );
  });

  test("the location takes precedence over the url as the livestream source", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = eventWith({
      location: "Discourse HQ, Denver",
      url: "https://zoom.us/j/123456789",
    });
    await renderAdvanced(event);

    assert
      .dom(`[data-name="livestream"]`)
      .doesNotExist("a venue event is not streamed from its companion link");
  });

  test("advanced screen hides the url field behind an add button when unset", async function (assert) {
    const event = eventWith();
    await renderAdvanced(event);

    assert.dom(`[data-name="url"] input`).doesNotExist("starts collapsed");
    assert
      .dom(`[data-name="location"] label`)
      .includesText(
        "Location or URL",
        "location covers both meanings while it is the only link field"
      );

    await click(".add-event-url");

    assert.dom(`[data-name="url"] input`).exists("the add button reveals it");
    assert
      .dom(`[data-name="location"] label`)
      .doesNotIncludeText(
        "or URL",
        "the label narrows once url has its own field"
      );
  });

  test("coerces end an hour after start when the picked end time is not after start", async function (assert) {
    const event = eventWith({ ends_at: "2022-07-01T12:00:00Z" });
    await renderAdvanced(event);

    const toTime = selectKit(".to .d-time-input .select-kit");
    await toTime.expand();
    await toTime.selectRowByName("10:00 AM");

    assert.strictEqual(
      moment(event.endsAt).toISOString(),
      "2022-07-01T11:00:00.000Z",
      "an end time at or before start is pushed an hour past start"
    );
  });
});
