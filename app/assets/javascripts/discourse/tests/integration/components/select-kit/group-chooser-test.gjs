import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import GroupChooser from "select-kit/components/group-chooser";

module("Integration | Component | select-kit/group-chooser", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = selectKit();
  });

  test("limiting the displayed groups", async function (assert) {
    const content = [
      {
        id: 1,
        name: "A",
      },
      {
        id: 2,
        name: "AB",
      },
      {
        id: 3,
        name: "ABC",
      },
    ];
    await render(
      <template>
        <GroupChooser
          @content={{content}}
          @options={{hash displayedGroupsLimit=1}}
        />
      </template>
    );

    await this.subject.expand();

    assert.strictEqual(
      this.subject.rows().length,
      1,
      "only 1 group is displayed"
    );
    assert.strictEqual(
      this.subject.rowByIndex(0).name(),
      "A",
      "the first group in the list is displayed"
    );

    assert
      .dom(this.subject.el().querySelector(".filter-for-more"))
      .exists("has indicator that there are more groups");

    await this.subject.fillInFilter("AB");

    assert.strictEqual(
      this.subject.rows().length,
      1,
      "only 1 group is displayed"
    );
    assert.strictEqual(
      this.subject.rowByIndex(0).name(),
      "AB",
      "the first group that matches the filter in the list is displayed"
    );
    assert
      .dom(this.subject.el().querySelector(".filter-for-more"))
      .exists("has indicator that there are more groups matching the filter");

    await this.subject.fillInFilter("C");

    assert.strictEqual(
      this.subject.rows().length,
      1,
      "only 1 group is displayed"
    );
    assert.strictEqual(
      this.subject.rowByIndex(0).name(),
      "ABC",
      "the first group that matches the filter in the list is displayed"
    );
    assert
      .dom(this.subject.el().querySelector(".filter-for-more"))
      .doesNotExist(
        "doesn't have an indicator when there are no more matching elements"
      );
  });
});
