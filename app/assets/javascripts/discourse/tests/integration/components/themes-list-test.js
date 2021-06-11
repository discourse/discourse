import Theme, { COMPONENTS, THEMES } from "admin/models/theme";
import I18n from "I18n";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | themes-list", function (hooks) {
  setupRenderingTest(hooks);
  componentTest("current tab is themes", {
    template: hbs`{{themes-list themes=themes components=components currentTab=currentTab}}`,
    beforeEach() {
      this.themes = [1, 2, 3, 4, 5].map((num) =>
        Theme.create({ name: `Theme ${num}` })
      );
      this.components = [1, 2, 3, 4, 5].map((num) =>
        Theme.create({
          name: `Child ${num}`,
          component: true,
          parentThemes: [this.themes[num - 1]],
          parent_themes: [1, 2, 3, 4, 5],
        })
      );
      this.setProperties({
        themes: this.themes,
        components: this.components,
        currentTab: THEMES,
      });
    },

    test(assert) {
      assert.equal(
        queryAll(".themes-tab").hasClass("active"),
        true,
        "themes tab is active"
      );
      assert.equal(
        queryAll(".components-tab").hasClass("active"),
        false,
        "components tab is not active"
      );

      assert.equal(
        queryAll(".inactive-indicator").index(),
        -1,
        "there is no inactive themes separator when all themes are inactive"
      );
      assert.equal(count(".themes-list-item"), 5, "displays all themes");

      [2, 3].forEach((num) => this.themes[num].set("user_selectable", true));
      this.themes[4].set("default", true);
      this.set("themes", this.themes);
      const names = [4, 2, 3, 0, 1].map((num) => this.themes[num].get("name")); // default theme always on top, followed by user-selectable ones and then the rest
      assert.deepEqual(
        Array.from(queryAll(".themes-list-item .name")).map((node) =>
          node.innerText.trim()
        ),
        names,
        "sorts themes correctly"
      );
      assert.equal(
        queryAll(".inactive-indicator").index(),
        3,
        "the separator is in the right location"
      );

      this.themes.forEach((theme) => theme.set("user_selectable", true));
      this.set("themes", this.themes);
      assert.equal(
        queryAll(".inactive-indicator").index(),
        -1,
        "there is no inactive themes separator when all themes are user-selectable"
      );

      this.set("themes", []);
      assert.equal(
        count(".themes-list-item"),
        1,
        "shows one entry with a message when there is nothing to display"
      );
      assert.equal(
        queryAll(".themes-list-item span.empty").text().trim(),
        I18n.t("admin.customize.theme.empty"),
        "displays the right message"
      );
    },
  });

  componentTest("current tab is components", {
    template: hbs`{{themes-list themes=themes components=components currentTab=currentTab}}`,
    beforeEach() {
      this.themes = [1, 2, 3, 4, 5].map((num) =>
        Theme.create({ name: `Theme ${num}` })
      );
      this.components = [1, 2, 3, 4, 5].map((num) =>
        Theme.create({
          name: `Child ${num}`,
          component: true,
          parentThemes: [this.themes[num - 1]],
          parent_themes: [1, 2, 3, 4, 5],
        })
      );
      this.setProperties({
        themes: this.themes,
        components: this.components,
        currentTab: COMPONENTS,
      });
    },

    test(assert) {
      assert.equal(
        queryAll(".components-tab").hasClass("active"),
        true,
        "components tab is active"
      );
      assert.equal(
        queryAll(".themes-tab").hasClass("active"),
        false,
        "themes tab is not active"
      );

      assert.equal(
        queryAll(".inactive-indicator").index(),
        -1,
        "there is no separator"
      );
      assert.equal(count(".themes-list-item"), 5, "displays all components");

      this.set("components", []);
      assert.equal(
        count(".themes-list-item"),
        1,
        "shows one entry with a message when there is nothing to display"
      );
      assert.equal(
        queryAll(".themes-list-item span.empty").text().trim(),
        I18n.t("admin.customize.theme.empty"),
        "displays the right message"
      );
    },
  });
});
