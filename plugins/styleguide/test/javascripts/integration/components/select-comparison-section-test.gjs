import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import SelectComparison from "discourse/plugins/styleguide/discourse/components/sections/molecules/select-comparison";

const PAIRS = [
  "tag-chooser",
  "mini-tag-chooser",
  "tag-drop",
  "tags-intersection-chooser",
  "tag-dropdown",
  "tag-group-chooser",
];

const side = (pair, which) =>
  `.styleguide-select-comparison__pair[data-pair="${pair}"] .styleguide-select-comparison__${which}`;

module("Styleguide | Integration | select comparison", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.tagging_enabled = true;
    pretender.get("/tags/filter/search", () => response({ results: [] }));
    pretender.get("/tags/list.json", () => response({ list_tags: [] }));
    pretender.get("/tag_groups/filter/search", () => response({ results: [] }));
    this.routeTo = sinon.stub(DiscourseURL, "routeTo");
    this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
  });

  for (const flag of [false, true]) {
    test(`every pair shows both controls with the flag ${flag ? "on" : "off"}`, async function (assert) {
      this.siteSettings.enable_new_select_controls = flag;

      await render(<template><SelectComparison /></template>);

      for (const pair of PAIRS) {
        assert.dom(`${side(pair, "legacy")} .select-kit`).exists(pair);
        assert.dom(`${side(pair, "legacy")} .d-select`).doesNotExist(pair);
        assert.dom(`${side(pair, "new")} .d-select`).exists(pair);
        assert.dom(`${side(pair, "new")} .select-kit`).doesNotExist(pair);
      }
    });
  }

  test("picking in a tag drop updates the demo instead of navigating", async function (assert) {
    await render(<template><SelectComparison /></template>);

    const legacy = selectKit(`${side("tag-drop", "legacy")} .select-kit`);
    await legacy.expand();
    await legacy.selectRowByValue("no-tags");

    await click(`${side("tag-drop", "new")} .d-select__trigger`);
    const noTags = findAll("[role='option']").find((row) =>
      row.textContent.includes(i18n("tagging.selector_no_tags"))
    );
    await click(noTags);

    assert
      .dom(`${side("tag-drop", "legacy")} .styleguide-select-comparison__value`)
      .includesText("none", "the legacy pick updates the demo");
    assert
      .dom(`${side("tag-drop", "new")} .styleguide-select-comparison__value`)
      .includesText("none", "the new pick updates the demo");
    assert.true(this.routeTo.notCalled, "no route change");
    assert.true(this.routeToUrl.notCalled, "no URL change");
  });
});
