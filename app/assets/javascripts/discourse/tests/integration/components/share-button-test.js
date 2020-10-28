import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";

moduleForComponent("share-button", { integration: true });

componentTest("share button", {
  template: '{{share-button url="https://eviltrout.com"}}',

  test(assert) {
    assert.ok(queryAll(`button.share`).length, "it has all the classes");

    assert.ok(
      queryAll('button[data-share-url="https://eviltrout.com"]').length,
      "it has the data attribute for sharing"
    );
  },
});
