import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import TagGroupList from "discourse/admin/components/site-settings/tag-group-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class State {
  @tracked value = "";
}

module(
  "Integration | Component | SiteSettings | TagGroupList",
  function (hooks) {
    setupRenderingTest(hooks);

    test("reports changes as a pipe-joined string and follows @value", async function (assert) {
      const state = new State();
      const changes = [];
      const changeValue = (value) => {
        changes.push(value);
        state.value = value;
      };

      await render(
        <template>
          <TagGroupList
            @changeValueCallback={{changeValue}}
            @value={{state.value}}
          />
        </template>
      );

      const subject = selectKit(".tag-group-chooser");
      await subject.expand();
      await subject.selectRowByName("TagGroup1");

      assert.deepEqual(changes, ["TagGroup1"], "reports the picked group");

      state.value = "TagGroup2";
      await settled();

      assert.strictEqual(
        subject.header().value(),
        "TagGroup2",
        "renders a value set by the caller"
      );
    });
  }
);
