import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { restoreBaseUri, setupURL } from "discourse/lib/get-url";
import User from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import CalendarPrompt from "discourse/plugins/discourse-events/discourse/components/discourse-post-event/calendar-prompt";
import MoreMenu from "discourse/plugins/discourse-events/discourse/components/discourse-post-event/more-menu";

async function exportCalendar(context, calendar) {
  context.currentUser.set(
    "user_option.default_calendar",
    context.useModal ? "none_selected" : calendar
  );

  await render(
    <template>
      <ModalContainer />
      {{#if context.fromMenu}}
        <MoreMenu @event={{context.event}} />
      {{else}}
        <CalendarPrompt @event={{context.event}} />
      {{/if}}
    </template>
  );

  if (context.fromMenu) {
    await click(".discourse-post-event-more-menu-trigger");
    await click(".add-to-calendar button");
  } else {
    await click(".event-calendar-prompt__actions .btn-primary");
  }

  if (context.useModal) {
    await formKit().field("calendar").select(calendar);
    await click(".download-calendar-modal .btn-primary");
  }
}

function assertGoogleDetails(assert, context, expected) {
  assert.true(context.openWindow.calledOnce, "opens one calendar draft");
  const url = new URL(context.openWindow.firstCall.args[0]);
  assert.strictEqual(
    url.searchParams.get("details"),
    expected,
    "Google Calendar details preserve the description and topic URL"
  );
}

async function assertIcsDetails(assert, context, expected) {
  assert.true(context.createObjectURL.calledOnce, "creates one ICS download");
  const file = context.createObjectURL.firstCall.args[0];
  const ics = (await file.text()).replace(/\r\n[ \t]/g, "");
  const details = ics
    .split("\r\n")
    .find((line) => line.startsWith("DESCRIPTION:"))
    ?.slice("DESCRIPTION:".length);
  assert.strictEqual(
    details,
    expected,
    "ICS details preserve the escaped description and topic URL"
  );
}

module("Integration | Component | EventCalendarExport", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    setupURL(null, "https://forum.example", "");
    sinon.stub(User, "current").returns(this.currentUser);
    this.openWindow = sinon.stub(window, "open");
    this.createObjectURL = sinon
      .stub(URL, "createObjectURL")
      .returns("blob:calendar-export");
    sinon.stub(HTMLAnchorElement.prototype, "click");
    this.event = {
      name: "Workshop",
      startsAt: "2026-11-01T10:00:00Z",
      endsAt: "2026-11-01T11:00:00Z",
      post: { url: "/t/workshop/123", topic: { title: "Workshop" } },
      creator: { username: "eviltrout" },
    };
  });

  hooks.afterEach(function () {
    restoreBaseUri();
  });

  module("Event menu", function (menuHooks) {
    menuHooks.beforeEach(function () {
      this.fromMenu = true;
    });

    module("Saved preference", function (preferenceHooks) {
      preferenceHooks.beforeEach(function () {
        this.useModal = false;
      });

      test("Google Calendar includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("Google Calendar includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "Bring snacks; tea, coffee\nC:\\notes\nhttps://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "Bring snacks\\; tea\\, coffee\\nC:\\\\notes\\nhttps://forum.example/t/workshop/123"
        );
      });
    });

    module("Calendar modal", function (modalHooks) {
      modalHooks.beforeEach(function () {
        this.useModal = true;
      });

      test("Google Calendar includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("Google Calendar includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "Bring snacks; tea, coffee\nC:\\notes\nhttps://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "Bring snacks\\; tea\\, coffee\\nC:\\\\notes\\nhttps://forum.example/t/workshop/123"
        );
      });
    });
  });

  module("RSVP prompt", function (promptHooks) {
    promptHooks.beforeEach(function () {
      this.fromMenu = false;
    });

    module("Saved preference", function (preferenceHooks) {
      preferenceHooks.beforeEach(function () {
        this.useModal = false;
      });

      test("Google Calendar includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("Google Calendar includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "Bring snacks; tea, coffee\nC:\\notes\nhttps://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "Bring snacks\\; tea\\, coffee\\nC:\\\\notes\\nhttps://forum.example/t/workshop/123"
        );
      });
    });

    module("Calendar modal", function (modalHooks) {
      modalHooks.beforeEach(function () {
        this.useModal = true;
      });

      test("Google Calendar includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("Google Calendar includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "google");

        assertGoogleDetails(
          assert,
          this,
          "Bring snacks; tea, coffee\nC:\\notes\nhttps://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL without a description", async function (assert) {
        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "https://forum.example/t/workshop/123"
        );
      });

      test("ICS includes the topic URL with a description", async function (assert) {
        this.event.description = "Bring snacks; tea, coffee\nC:\\notes";

        await exportCalendar(this, "ics");

        await assertIcsDetails(
          assert,
          this,
          "Bring snacks\\; tea\\, coffee\\nC:\\\\notes\\nhttps://forum.example/t/workshop/123"
        );
      });
    });
  });
});
