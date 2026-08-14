import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PostEventBuilder from "../../discourse/components/modal/post-event-builder";
import DiscoursePostEventEvent from "../../discourse/models/discourse-post-event-event";

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

  test("advanced screen renders an existing image upload as its URL", async function (assert) {
    const event = DiscoursePostEventEvent.create({
      name: "My event",
      starts_at: "2022-07-01T10:00:00Z",
      ends_at: "2022-07-01T11:00:00Z",
      timezone: "UTC",
      status: "public",
      reminders: [],
      raw_invitees: [],
      custom_fields: {},
      image_upload: {
        url: "/uploads/default/original/1X/test-event-image.png",
        short_url: "upload://test-event-image",
      },
    });

    const model = {
      event,
      initialScreen: "advanced",
      onUpdate: () => {},
      toolbarEvent: {},
    };
    const closeModal = () => {};

    await render(
      <template>
        <PostEventBuilder
          @inline={{true}}
          @model={{model}}
          @closeModal={{closeModal}}
        />
      </template>
    );

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

    const event = DiscoursePostEventEvent.create({
      name: "My event",
      starts_at: "2022-07-01T10:00:00Z",
      ends_at: "2022-07-01T11:00:00Z",
      timezone: "UTC",
      status: "public",
      reminders: [],
      raw_invitees: [],
      custom_fields: {},
    });

    const model = {
      event,
      initialScreen: "advanced",
      onUpdate: () => {},
      toolbarEvent: {},
    };
    const closeModal = () => {};

    await render(
      <template>
        <PostEventBuilder
          @inline={{true}}
          @model={{model}}
          @closeModal={{closeModal}}
        />
      </template>
    );

    assert
      .dom(`[data-name="customFields.field_aa"] input`)
      .exists("renders the dashed custom field without crashing");
  });

  test("clears livestream when the location stops being a URL", async function (assert) {
    this.siteSettings.chat_enabled = true;

    const event = DiscoursePostEventEvent.create({
      name: "My event",
      starts_at: "2022-07-01T10:00:00Z",
      ends_at: "2022-07-01T11:00:00Z",
      timezone: "UTC",
      status: "public",
      reminders: [],
      raw_invitees: [],
      custom_fields: {},
      location: "https://zoom.us/j/123456789",
      livestream: true,
    });

    const model = {
      event,
      initialScreen: "advanced",
      onUpdate: () => {},
      toolbarEvent: {},
    };
    const closeModal = () => {};

    await render(
      <template>
        <PostEventBuilder
          @inline={{true}}
          @model={{model}}
          @closeModal={{closeModal}}
        />
      </template>
    );

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

    const event = DiscoursePostEventEvent.create({
      name: "My event",
      starts_at: "2022-07-01T10:00:00Z",
      ends_at: "2022-07-01T11:00:00Z",
      timezone: "UTC",
      status: "public",
      reminders: [],
      raw_invitees: [],
      custom_fields: {},
    });

    let updatedEvent = null;
    const model = {
      event,
      initialScreen: "advanced",
      onUpdate: (startsAt, endsAt, savedEvent) => {
        updatedEvent = savedEvent;
      },
      toolbarEvent: {},
    };
    const closeModal = () => {};

    await render(
      <template>
        <PostEventBuilder
          @inline={{true}}
          @model={{model}}
          @closeModal={{closeModal}}
        />
      </template>
    );

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

  test("typed custom field survives a compact-screen edit in between", async function (assert) {
    this.siteSettings.discourse_post_event_allowed_custom_fields = "test1";

    const event = DiscoursePostEventEvent.create({
      name: "My event",
      starts_at: "2022-07-01T10:00:00Z",
      ends_at: "2022-07-01T11:00:00Z",
      timezone: "UTC",
      status: "public",
      reminders: [],
      raw_invitees: [],
      custom_fields: { test1: "seeded" },
    });

    let updatedEvent = null;
    const model = {
      event,
      initialScreen: "compact",
      onUpdate: (startsAt, endsAt, savedEvent) => {
        updatedEvent = savedEvent;
      },
      toolbarEvent: {},
    };
    const closeModal = () => {};

    await render(
      <template>
        <PostEventBuilder
          @inline={{true}}
          @model={{model}}
          @closeModal={{closeModal}}
        />
      </template>
    );

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
});
