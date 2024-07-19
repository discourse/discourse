import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

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

    this.site.set("top_tags_with_groups", [
      {
        tag_name: "jeff",
        tag_group_names: ["group1", "group2"],
        sum_topic_count: 4,
      },
      { tag_name: "neil", tag_group_names: ["group1"], sum_topic_count: 3 },
      { tag_name: "arpit", tag_group_names: [], sum_topic_count: 2 },
      { tag_name: "régis", tag_group_names: [], sum_topic_count: 1 },
    ]);

    pretender.get("/tags/filter/search", (params) => {
      if (params.queryParams.q === "dav") {
        return response({
          results: [
            {
              id: "David",
              name: "David",
              count: 2,
              pm_only: false,
              tag_group_names: ["group1"],
            },
          ],
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
      I18n.t("tagging.selector_remove_filter"),
      "it has the correct label for removing the tag filter"
    );
    assert.strictEqual(
      content[1].name,
      I18n.t("tagging.selector_no_tags"),
      "it has the translated label for no-tags"
    );

    const rows = this.subject.rows();
    assert.strictEqual(
      rows[2].querySelector(".discourse-tag").dataset.tagGroups,
      "group1, group2",
      "it has the data-tag-groups for grouped tags"
    );
    assert.strictEqual(
      rows[4].querySelector(".discourse-tag").dataset.tagGroups,
      undefined,
      "it does not have data-tag-groups the ungroupped tags"
    );

    await this.subject.fillInFilter("dav");

    const row0 = this.subject.rows()[0];

    assert.strictEqual(
      row0.textContent.trim(),
      "David",
      "it has no tag count when filtering in a category context"
    );

    assert.strictEqual(
      row0.querySelector(".discourse-tag").dataset.tagGroups,
      "group1",
      "it has tag groups when filtering in a category context"
    );
  });

  test("default global (no category)", async function (assert) {
    await render(hbs`<TagDrop />`);

    await this.subject.expand();
    await this.subject.fillInFilter("dav");

    const row = this.subject.rows()[0];
    assert.strictEqual(
      row.textContent.trim(),
      "David x2",
      "it has the tag count"
    );
  });

  test("default global (no category)", async function (assert) {
    this.siteSettings.max_tags_in_filter_list = 3;
    await render(hbs`<TagDrop />`);

    await this.subject.expand();
    assert.dom(".filter-for-more").exists("it has the 'filter for more' note");

    const rows = this.subject.rows();
    assert.strictEqual(
      rows[1].querySelector(".discourse-tag").dataset.tagGroups,
      "group1, group2",
      "it has the data-tag-groups for grouped tags"
    );
    assert.strictEqual(
      rows[3].querySelector(".discourse-tag").dataset.tagGroups,
      undefined,
      "it does not have data-tag-groups the ungroupped tags"
    );

    await this.subject.fillInFilter("dav");
    assert
      .dom(".filter-for-more")
      .doesNotExist("it does not have the 'filter for more' note");
  });
});
