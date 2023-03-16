import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import I18n from "I18n";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function initTags(context) {
  const categories = context.site.categoriesList;
  const category = categories.findBy("id", 2);

  // top_tags
  context.setProperties({
    currentCategory: category,
    tagId: "jeff",
  });
}

module("Integration | Component | select-kit/tag-drop", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());

    this.site.set("top_tags", ["jeff", "neil", "arpit", "régis"]);

    pretender.get("/tags/filter/search", (params) => {
      if (params.queryParams.q === "dav") {
        return response({
          results: [{ id: "David", name: "David", count: 2, pm_only: false }],
        });
      }
    });
  });

  test("default", async function (assert) {
    initTags(this);

    await render(hbs`
      <TagDrop
        @currentCategory={{this.currentCategory}}
        @tagId={{this.tagId}}
        @options={{hash
          tagId=this.tagId
        }}
      />
    `);

    await this.subject.expand();

    const content = this.subject.displayedContent();

    assert.strictEqual(
      content[0].name,
      I18n.t("tagging.selector_no_tags"),
      "it has the translated label for no-tags"
    );
    assert.strictEqual(
      content[1].name,
      I18n.t("tagging.selector_all_tags"),
      "it has the correct label for all-tags"
    );

    await this.subject.fillInFilter("dav");

    assert.strictEqual(
      this.subject.rows()[0].textContent.trim(),
      "David",
      "it has no tag count when filtering in a category context"
    );
  });

  test("default global (no category)", async function (assert) {
    await render(hbs`<TagDrop />`);

    await this.subject.expand();
    await this.subject.fillInFilter("dav");

    assert.strictEqual(
      this.subject.rows()[0].textContent.trim(),
      "David x2",
      "it has the tag count"
    );
  });
});
