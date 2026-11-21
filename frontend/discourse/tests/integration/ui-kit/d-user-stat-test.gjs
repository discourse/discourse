import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { durationTiny, number } from "discourse/lib/formatter";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DUserStat from "discourse/ui-kit/d-user-stat";
import I18n from "discourse-i18n";

module("Integration | ui-kit | DUserStat", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    I18n.translations[I18n.locale].js.test_user_stat = {
      label: { one: "<b>%{count}</b> post", other: "<b>%{count}</b> posts" },
    };
  });

  test("formats the value as a number by default", async function (assert) {
    await render(
      <template>
        <DUserStat @label="test_user_stat.label" @value={{1500}} />
      </template>
    );

    assert
      .dom(".user-stat .value .number")
      .hasText(number(1500), "the value is a compact number");
  });

  test("formats a duration value", async function (assert) {
    await render(
      <template>
        <DUserStat
          @label="test_user_stat.label"
          @type="duration"
          @value={{5400}}
        />
      </template>
    );

    assert
      .dom(".user-stat .value")
      .hasText(durationTiny(5400), "the value is a tiny duration");
  });

  test("shows any other type as given", async function (assert) {
    await render(
      <template>
        <DUserStat @label="test_user_stat.label" @type="string" @value="1500" />
      </template>
    );

    assert
      .dom(".user-stat .value")
      .hasText("1500", "the value is not formatted");
    assert
      .dom(".user-stat .value .number")
      .doesNotExist("no number markup is added");
  });

  test("renders the label as HTML, pluralized by the value", async function (assert) {
    await render(
      <template>
        <DUserStat @label="test_user_stat.label" @value={{1}} />
      </template>
    );

    assert
      .dom(".user-stat .label b")
      .hasText("1", "the label HTML is rendered, not escaped");
    assert
      .dom(".user-stat .label")
      .hasText("1 post", "the label uses the singular for one");
  });

  test("shows @icon and @rawTitle", async function (assert) {
    await render(
      <template>
        <DUserStat
          @icon="heart"
          @label="test_user_stat.label"
          @rawTitle="Exactly 2 posts"
          @value={{2}}
        />
      </template>
    );

    assert
      .dom(".user-stat .label .d-icon-heart")
      .exists("the icon is shown in the label");
    assert
      .dom(".user-stat .value")
      .hasAttribute(
        "title",
        "Exactly 2 posts",
        "@rawTitle is the value's title"
      );
  });
});
