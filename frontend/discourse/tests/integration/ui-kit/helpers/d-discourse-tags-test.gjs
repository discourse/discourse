import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";

module("Integration | ui-kit | Helper | dDiscourseTags", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the topic's tags with the options", async function (assert) {
    const topic = EmberObject.create({ tags: ["cat", "dog"] });

    await render(
      <template>{{dDiscourseTags topic className="gizmo"}}</template>
    );

    assert.dom("ul.discourse-tags.gizmo li").exists({ count: 2 });
    assert.dom(".discourse-tag[data-tag-name='dog']").exists();
  });
});
