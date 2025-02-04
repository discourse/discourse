import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import TagDrop from "select-kit/components/tag-drop";

module("Integration | Component | select-kit/tag-drop", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = selectKit();

    this.site.top_tags = ["jeff", "neil", "arpit", "régis"];

    pretender.get("/tags/filter/search", (params) => {
      if (params.queryParams.q === "dav") {
        return response({
          results: [{ id: "David", name: "David", count: 2, pm_only: false }],
        });
      }
    });
  });

  test("default", async function (assert) {
    const categories = this.site.categoriesList;
    const category = categories.findBy("id", 2);

    await render(<template>
      <TagDrop
        @currentCategory={{category}}
        @tagId="jeff"
        @options={{hash tagId="jeff"}}
      />
    </template>);

    await this.subject.expand();

    const content = this.subject.displayedContent();

    assert.strictEqual(
      content[0].name,
      i18n("tagging.selector_remove_filter"),
      "has the correct label for removing the tag filter"
    );
    assert.strictEqual(
      content[1].name,
      i18n("tagging.selector_no_tags"),
      "has the translated label for no-tags"
    );

    await this.subject.fillInFilter("dav");

    assert
      .dom(this.subject.rows()[0])
      .hasText(
        "David",
        "has no tag count when filtering in a category context"
      );
  });

  test("default global (no category)", async function (assert) {
    await render(<template><TagDrop /></template>);

    await this.subject.expand();
    await this.subject.fillInFilter("dav");

    assert.dom(this.subject.rows()[0]).hasText("David x2", "has the tag count");
  });

  test("default global (no category, max tags)", async function (assert) {
    this.siteSettings.max_tags_in_filter_list = 3;
    await render(<template><TagDrop /></template>);

    await this.subject.expand();
    assert.dom(".filter-for-more").exists("has the 'filter for more' note");

    await this.subject.fillInFilter("dav");
    assert
      .dom(".filter-for-more")
      .doesNotExist("does not have the 'filter for more' note");
  });
});
