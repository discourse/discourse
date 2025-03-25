import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ThemesListItem from "admin/components/themes-list-item";
import Theme from "admin/models/theme";

module("Integration | Component | themes-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("default theme", async function (assert) {
    const self = this;

    this.set("theme", Theme.create({ name: "Test", default: true }));

    await render(<template><ThemesListItem @theme={{self.theme}} /></template>);

    assert.dom(".d-icon-check").exists("shows default theme icon");
  });

  test("pending updates", async function (assert) {
    const self = this;

    this.set(
      "theme",
      Theme.create({ name: "Test", remote_theme: { commits_behind: 6 } })
    );

    await render(<template><ThemesListItem @theme={{self.theme}} /></template>);

    assert.dom(".d-icon-arrows-rotate").exists("shows pending update icon");
  });

  test("broken theme", async function (assert) {
    const self = this;

    this.set(
      "theme",
      Theme.create({
        name: "Test",
        theme_fields: [{ name: "scss", type_id: 1, error: "something" }],
      })
    );

    await render(<template><ThemesListItem @theme={{self.theme}} /></template>);

    assert.dom(".d-icon-circle-exclamation").exists("shows broken theme icon");
  });

  test("with children", async function (assert) {
    const self = this;

    this.childrenList = [1, 2, 3, 4, 5].map((num) =>
      Theme.create({ name: `Child ${num}`, component: true })
    );

    this.set(
      "theme",
      Theme.create({
        name: "Test",
        childThemes: this.childrenList,
        default: true,
      })
    );

    await render(<template><ThemesListItem @theme={{self.theme}} /></template>);

    assert.deepEqual(
      document
        .querySelector(".components")
        .innerText.split(",")
        .map((n) => n.trim()),
      this.childrenList.splice(0, 4).map((theme) => theme.get("name")),
      "lists the first 4 children"
    );
    assert
      .dom(".others-count")
      .hasText(
        i18n("admin.customize.theme.and_x_more", { count: 1 }),
        "shows count of remaining children"
      );
  });
});
