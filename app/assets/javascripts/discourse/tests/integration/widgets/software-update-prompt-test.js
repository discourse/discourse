import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import sinon from "sinon";
import {
  discourseModule,
  fakeTime,
  publishToMessageBus,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

let clock = null;
discourseModule(
  "Integration | Component | software-update-prompt",
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
        template: hbs`{{software-update-prompt}}`,

        test(assert) {
          assert.ok(
            queryAll("div.software-update-prompt.require-software-refresh")
              .length === 0,
            "it does not have the class to show the prompt"
          );
          assert.equal(
            queryAll("div.software-update-prompt")[0].getAttribute(
              "aria-hidden"
            ),
            "",
            "it does have the aria-hidden attribute"
          );

          publishToMessageBus("/global/asset-version", "somenewversion");

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
