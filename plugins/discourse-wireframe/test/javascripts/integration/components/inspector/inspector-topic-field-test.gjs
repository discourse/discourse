import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import InspectorTopicField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-topic-field";

// Minimal FormKit FieldData stand-in: the control reads `.value` and writes
// through `.set`, recording each commit for assertions.
function makeCustom(value) {
  return {
    value,
    commits: [],
    set(next) {
      this.value = next;
      this.commits.push(next);
    },
  };
}

module("Integration | Wireframe | InspectorTopicField", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // The chooser searches topics through `/search/query`; back it with the
    // shared search fixture so a filter surfaces selectable topic rows.
    pretender.get("/search/query", () =>
      response(searchFixtures["search/query"])
    );
  });

  test("resolves a saved id to its topic title, not the raw id", async function (assert) {
    // The saved value is a bare id; the field must fetch the topic so the
    // chooser shows the title instead of the number.
    pretender.get("/t/2179.json", () =>
      response({
        id: 2179,
        fancy_title: "Development mode super slow",
        title: "Development mode super slow",
      })
    );

    const custom = makeCustom(2179);

    await render(
      <template><InspectorTopicField @custom={{custom}} /></template>
    );

    assert.dom(".topic-chooser").exists("mounts the topic chooser");

    const header = selectKit(".topic-chooser").header();
    assert.strictEqual(
      header.label(),
      "Development mode super slow",
      "the header shows the resolved topic title"
    );
    assert.notStrictEqual(
      header.label(),
      "2179",
      "the header does not show the id"
    );
  });

  test("writes the chosen topic id through the field", async function (assert) {
    const custom = makeCustom(null);

    await render(
      <template><InspectorTopicField @custom={{custom}} /></template>
    );

    const chooser = selectKit(".topic-chooser");
    await chooser.expand();
    await chooser.fillInFilter("dev");
    await chooser.selectRowByValue(2179);

    assert.deepEqual(
      custom.commits,
      [2179],
      "commits the selected topic id back to the field"
    );
  });
});
