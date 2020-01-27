import componentTest from "helpers/component-test";
import Theme, { THEMES, COMPONENTS } from "admin/models/theme";

moduleForComponent("themes-list", { integration: true });

const themes = [1, 2, 3, 4, 5].map(num =>
  Theme.create({ name: `Theme ${num}` })
);
const components = [1, 2, 3, 4, 5].map(num =>
  Theme.create({
    name: `Child ${num}`,
    component: true,
    parentThemes: [themes[num - 1]],
    parent_themes: [1, 2, 3, 4, 5]
  })
);

componentTest("current tab is themes", {
  template:
    "{{themes-list themes=themes components=components currentTab=currentTab}}",
  beforeEach() {
    this.setProperties({
      themes,
      components,
      currentTab: THEMES
    });
  },

  test(assert) {
    assert.equal(
      find(".themes-tab").hasClass("active"),
      true,
      "themes tab is active"
    );
    assert.equal(
      find(".components-tab").hasClass("active"),
      false,
      "components tab is not active"
    );

    assert.equal(
      find(".inactive-indicator").index(),
      -1,
      "there is no inactive themes separator when all themes are inactive"
    );
    assert.equal(find(".themes-list-item").length, 5, "displays all themes");

    [2, 3].forEach(num => themes[num].set("user_selectable", true));
    themes[4].set("default", true);
    this.set("themes", themes);
    const names = [4, 2, 3, 0, 1].map(num => themes[num].get("name")); // default theme always on top, followed by user-selectable ones and then the rest
    assert.deepEqual(
      Array.from(find(".themes-list-item").find(".name")).map(node =>
        node.innerText.trim()
      ),
      names,
      "sorts themes correctly"
    );
    assert.equal(
      find(".inactive-indicator").index(),
      3,
      "the separator is in the right location"
    );

    themes.forEach(theme => theme.set("user_selectable", true));
    this.set("themes", themes);
    assert.equal(
      find(".inactive-indicator").index(),
      -1,
      "there is no inactive themes separator when all themes are user-selectable"
    );

    this.set("themes", []);
    assert.equal(
      find(".themes-list-item").length,
      1,
      "shows one entry with a message when there is nothing to display"
    );
    assert.equal(
      find(".themes-list-item span.empty")
        .text()
        .trim(),
      I18n.t("admin.customize.theme.empty"),
      "displays the right message"
    );
  }
});

componentTest("current tab is components", {
  template:
    "{{themes-list themes=themes components=components currentTab=currentTab}}",
  beforeEach() {
    this.setProperties({
      themes,
      components,
      currentTab: COMPONENTS
    });
  },

  test(assert) {
    assert.equal(
      find(".components-tab").hasClass("active"),
      true,
      "components tab is active"
    );
    assert.equal(
      find(".themes-tab").hasClass("active"),
      false,
      "themes tab is not active"
    );

    assert.equal(
      find(".inactive-indicator").index(),
      -1,
      "there is no separator"
    );
    assert.equal(
      find(".themes-list-item").length,
      5,
      "displays all components"
    );

    this.set("components", []);
    assert.equal(
      find(".themes-list-item").length,
      1,
      "shows one entry with a message when there is nothing to display"
    );
    assert.equal(
      find(".themes-list-item span.empty")
        .text()
        .trim(),
      I18n.t("admin.customize.theme.empty"),
      "displays the right message"
    );
  }
});
