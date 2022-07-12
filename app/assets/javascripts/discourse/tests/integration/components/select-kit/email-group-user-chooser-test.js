import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { paste, query } from "discourse/tests/helpers/qunit-helpers";

module(
  "Integration | Component | select-kit/email-group-user-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("pasting", async function (assert) {
      await render(hbs`<EmailGroupUserChooser/>`);

      await this.subject.expand();
      await paste(query(".filter-input"), "foo,bar");

      assert.equal(this.subject.header().value(), "foo,bar");
    });
  }
);
