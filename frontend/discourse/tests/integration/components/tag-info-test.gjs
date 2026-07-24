import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TagInfo from "discourse/components/tag-info";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | TagInfo", function (hooks) {
  setupRenderingTest(hooks);

  function buildTagInfo(store, attrs = {}) {
    const { synonyms = [], ...rest } = attrs;
    return store.createRecord("tag-info", {
      id: 12,
      name: "planters",
      slug: "planters",
      tag_group_names: [],
      categories: [],
      category_restricted: false,
      ...rest,
      synonyms: synonyms.map((s) => store.createRecord("tag", s)),
    });
  }

  test("shows category_restricted message when restricted with no visible categories", async function (assert) {
    const store = this.owner.lookup("service:store");
    const tagInfo = buildTagInfo(store, {
      tag_group_names: ["Gardening"],
      categories: [],
      category_restricted: true,
    });

    await render(<template><TagInfo @tagInfo={{tagInfo}} /></template>);

    assert
      .dom(".tag-associations")
      .includesText("Gardening", "tag group is still shown");
    assert
      .dom(".tag-associations")
      .includesText(
        i18n("tagging.category_restricted"),
        "restricted message renders alongside the tag group"
      );
    assert
      .dom(".tag-associations")
      .doesNotIncludeText(
        i18n("tagging.default_info"),
        "default fallback is suppressed when restricted"
      );
  });

  test("hides category_restricted message when categories are visible", async function (assert) {
    const store = this.owner.lookup("service:store");
    const tagInfo = buildTagInfo(store, {
      categories: [
        {
          id: 7,
          name: "Outdoors",
          color: "000",
          text_color: "FFFFFF",
          slug: "outdoors",
        },
      ],
      category_restricted: true,
    });

    await render(<template><TagInfo @tagInfo={{tagInfo}} /></template>);

    assert.dom(".tag-associations .badge-category").exists();
    assert
      .dom(".tag-associations")
      .doesNotIncludeText(
        i18n("tagging.category_restricted"),
        "restricted message is not duplicated when categories render"
      );
  });

  test("shows default_info when there is nothing else to show", async function (assert) {
    const store = this.owner.lookup("service:store");
    const tagInfo = buildTagInfo(store);

    await render(<template><TagInfo @tagInfo={{tagInfo}} /></template>);

    assert
      .dom(".tag-associations")
      .includesText(i18n("tagging.default_info").replace(/<[^>]+>/g, ""));
  });
});
