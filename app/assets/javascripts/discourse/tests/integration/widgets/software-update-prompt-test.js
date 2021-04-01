import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import MessageBus from "message-bus-client";
import sinon from "sinon";
import {
  discourseModule,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

let clock = null;
discourseModule(
  "Integration | Component | Widget | software-update-prompt",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      clock = fakeTime("2019-12-10T08:00:00", "Australia/Brisbane", true);
    });

    hooks.afterEach(function () {
      clock.restore();
      sinon.restore();
    });

    componentTest(
      "software-update-prompt gets correct CSS class after messageBus message",
      {
        template: hbs`{{mount-widget widget="software-update-prompt" args=args}}`,

        beforeEach() {
          this.set("args", {});
        },

        test(assert) {
          assert.ok(
            queryAll("div.software-update-prompt.require-software-refresh")
              .length === 0,
            "it does not have the class to show the prompt"
          );

          // Mimic a messagebus message
          MessageBus.callbacks
            .filterBy("channel", "/global/asset-version")
            .map((c) => c.func("somenewversion"));

          clock.tick(1000 * 60 * 24 * 60 + 10);

          assert.ok(
            queryAll("div.software-update-prompt.require-software-refresh")
              .length === 1,
            "it does have the class to show the prompt"
          );
        },
      }
    );
  }
);
