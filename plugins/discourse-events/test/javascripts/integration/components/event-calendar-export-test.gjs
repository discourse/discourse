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

  for (const entryPoint of ["menu", "prompt"]) {
    for (const calendar of ["google", "ics"]) {
      for (const useModal of [false, true]) {
        for (const description of [
          null,
          "Bring snacks; tea, coffee\nC:\\notes",
        ]) {
          test(`${entryPoint} exports ${calendar} ${useModal ? "through the modal" : "with a saved preference"} ${description ? "with" : "without"} a description`, async function (assert) {
            this.event.description = description;
            this.currentUser.set(
              "user_option.default_calendar",
              useModal ? "none_selected" : calendar
            );
            this.fromMenu = entryPoint === "menu";

            await render(
              <template>
                <ModalContainer />
                {{#if this.fromMenu}}
                  <MoreMenu @event={{this.event}} />
                {{else}}
                  <CalendarPrompt @event={{this.event}} />
                {{/if}}
              </template>
            );

            if (this.fromMenu) {
              await click(".discourse-post-event-more-menu-trigger");
              await click(".add-to-calendar button");
            } else {
              await click(".event-calendar-prompt__actions .btn-primary");
            }

            if (useModal) {
              await formKit().field("calendar").select(calendar);
              await click(".download-calendar-modal .btn-primary");
            }

            const postUrl = "https://forum.example/t/workshop/123";
            const exportSpy =
              calendar === "google" ? this.openWindow : this.createObjectURL;
            assert.true(exportSpy.calledOnce, "exports the event once");

            let actualDetails;
            let expectedDetails;
            if (calendar === "google") {
              const url = new URL(this.openWindow.firstCall.args[0]);
              actualDetails = url.searchParams.get("details");
              expectedDetails = description
                ? `${description}\n${postUrl}`
                : postUrl;
            } else {
              const file = this.createObjectURL.firstCall.args[0];
              const ics = (await file.text()).replace(/\r\n[ \t]/g, "");
              actualDetails = ics
                .split("\r\n")
                .find((line) => line.startsWith("DESCRIPTION:"))
                ?.slice("DESCRIPTION:".length);
              expectedDetails = description
                ? `Bring snacks\\; tea\\, coffee\\nC:\\\\notes\\n${postUrl}`
                : postUrl;
            }
            assert.strictEqual(
              actualDetails,
              expectedDetails,
              "the exported description includes the topic URL and preserves the description"
            );
          });
        }
      }
    }
  }
});
