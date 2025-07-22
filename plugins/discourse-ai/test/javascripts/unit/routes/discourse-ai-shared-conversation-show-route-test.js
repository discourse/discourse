/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module(
  "Unit | Route | discourse-ai-shared-conversation-show",
  function (hooks) {
    setupTest(hooks);

    test("it redirects based on currentUser preference", function (assert) {
      const transition = {
        intent: { url: "https://www.discourse.org" },
        abort() {
          assert.ok(true, "transition.abort() was called");
        },
      };

      const route = this.owner.lookup(
        "route:discourse-ai-shared-conversation-show"
      );

      const windowOpenStub = sinon.stub(window, "open");
      const routeRedirectStub = sinon.stub(route, "redirect");

      // external_links_in_new_tab = true
      route.set("currentUser", {
        user_option: {
          external_links_in_new_tab: true,
        },
      });

      windowOpenStub.callsFake((url, target) => {
        assert.equal(
          url,
          "https://www.discourse.org",
          "window.open was called with the correct URL"
        );
        assert.equal(target, "_blank", 'window.open was called with "_blank"');
      });

      route.beforeModel(transition);

      // external_links_in_new_tab = false
      route.set("currentUser", {
        user_option: {
          external_links_in_new_tab: false,
        },
      });

      routeRedirectStub.callsFake((url) => {
        assert.equal(
          url,
          "https://www.discourse.org",
          "redirect was called with the correct URL"
        );
      });

      route.beforeModel(transition);
    });
  }
);
