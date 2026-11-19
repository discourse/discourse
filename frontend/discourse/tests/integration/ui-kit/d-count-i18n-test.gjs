import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import I18n, { i18n } from "discourse-i18n";

module("Integration | ui-kit | DCountI18n", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    I18n.translations[I18n.locale].js.test_count_i18n = {
      posts: { one: "<b>%{count}</b> post", other: "<b>%{count}</b> posts" },
      posts_new: {
        one: "<b>%{count}</b> new post",
        other: "<b>%{count}</b> new posts",
      },
    };
  });

  test("renders the pluralized translation as HTML", async function (assert) {
    await render(
      <template>
        <DCountI18n @count={{3}} @key="test_count_i18n.posts" />
      </template>
    );

    assert.dom("span b").hasText("3", "the translation HTML is rendered");
    assert.dom("span").hasText("3 posts", "the plural form is used");
  });

  test("appends @suffix to the key", async function (assert) {
    await render(
      <template>
        <DCountI18n @count={{1}} @key="test_count_i18n.posts" @suffix="_new" />
      </template>
    );

    assert.dom("span").hasText("1 new post", "the suffixed key is used");
  });

  test("uses the latest count for new topics when new is unified", async function (assert) {
    this.currentUser.set("unified_new_enabled", true);

    await render(
      <template><DCountI18n @count={{2}} @key="topic_count_new" /></template>
    );

    assert
      .dom("span")
      .hasText(
        i18n("topic_count_latest", { count: 2 }),
        "the key switches to topic_count_latest"
      );
  });
});
