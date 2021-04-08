import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  publishToMessageBus,
  queryAll,
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
            queryAll("div.software-update-prompt.require-software-refresh")
              .length === 0,
            "it does not have the class to show the prompt"
          );

          publishToMessageBus("/global/asset-version", "somenewversion");

          const done = assert.async();
          later(() => {
            assert.ok(
              queryAll("div.software-update-prompt.require-software-refresh")
                .length === 1,
              "it does have the class to show the prompt"
            );
            done();
          }, 10);
        },
      }
    );
  }
);
