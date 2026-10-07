import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const noop = () => {};

const user = {
  isUser: true,
  username: "sam",
  name: "Sam Saffron",
  avatar_template: "/letter_avatar_proxy/v4/letter/s/3be4f8/{size}.png",
  cssClasses: "is-online",
};
const email = { isEmail: true, username: "sam@example.com" };
const group = {
  isGroup: true,
  name: "team",
  full_name: "The Team",
  // Only users carry custom classes, so this one must be ignored.
  cssClasses: "is-ignored",
};

module("Integration | Component | UserAutocompleteResults", function (hooks) {
  setupRenderingTest(hooks);

  test("titles each kind of result by its own name field", async function (assert) {
    const results = [user, email, group];

    await render(
      <template>
        <UserAutocompleteResults
          @onSelect={{noop}}
          @results={{results}}
          @selectedIndex={{-1}}
        />
      </template>
    );

    assert.dom("li:nth-child(1) a").hasAttribute("title", "Sam Saffron");
    assert.dom("li:nth-child(2) a").hasAttribute("title", "sam@example.com");
    assert.dom("li:nth-child(3) a").hasAttribute("title", "The Team");
  });

  test("applies custom classes to users only, plus the selection", async function (assert) {
    const results = [user, email, group];

    await render(
      <template>
        <UserAutocompleteResults
          @onSelect={{noop}}
          @results={{results}}
          @selectedIndex={{2}}
        />
      </template>
    );

    assert.dom("li:nth-child(1) a").hasClass("is-online");
    assert.dom("li:nth-child(1) a").doesNotHaveClass("selected");
    assert.dom("li:nth-child(2) a").hasNoClass();
    assert.dom("li:nth-child(3) a").doesNotHaveClass("is-ignored");
    assert.dom("li:nth-child(3) a").hasClass("selected");
  });
});
