import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";

module("Integration | ui-kit | Helper | dDiscourseTag", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the tag with the options", async function (assert) {
    await render(<template>{{dDiscourseTag "foo" tagName="span"}}</template>);

    assert.dom("span.discourse-tag[data-tag-name='foo']").hasText("foo");
  });
});
