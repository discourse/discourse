import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { later } from "@ember/runloop";

discourseModule(
  "Integration | Component | software-update-prompt",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest(
      "software-update-prompt gets correct CSS class after messageBus message",
      {
        template: hbs`{{software-update-prompt}}`,

        test(assert) {
          assert.ok(
            !exists("div.software-update-prompt"),
            "it does not have the class to show the prompt"
          );

          publishToMessageBus("/global/asset-version", "somenewversion");

          const done = assert.async();
          later(() => {
            assert.equal(
              count("div.software-update-prompt.require-software-refresh"),
              1,
              "it does have the class to show the prompt"
            );
            done();
          }, 10);
        },
      }
    );
  }
);
