import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
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
});
