import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import QueryTagChooser from "discourse/plugins/discourse-data-explorer/discourse/components/query-tag-chooser";

class TestComponent extends Component {
  @tracked tags = [];

  @action
  updateTags(tags) {
    this.tags = tags;
  }

  <template>
    <QueryTagChooser
      @availableTags={{array "Default" "Staff"}}
      @onChange={{this.updateTags}}
      @value={{this.tags}}
    />
  </template>
}

module("Integration | Component | QueryTagChooser", function (hooks) {
  setupRenderingTest(hooks);

  test("selects an existing tag and creates a new tag", async function (assert) {
    await render(<template><TestComponent /></template>);

    const tags = selectKit(".query-tag-chooser");
    await tags.expand();
    assert.deepEqual(
      tags.displayedContent().map((tag) => tag.name),
      ["Default", "Staff"],
      "existing tags are offered"
    );

    await tags.selectRowByValue("Staff");
    await tags.fillInFilter("Monthly");

    assert
      .dom(".query-tag-chooser .select-kit-row[data-value='Monthly']")
      .exists("the entered tag can be created");

    await tags.selectRowByValue("Monthly");

    assert
      .dom(".query-tag-chooser .selected-content .selected-choice")
      .exists({ count: 2 }, "both tags are selected");
  });
});
