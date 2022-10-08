import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";
import Theme from "admin/models/theme";

module("Integration | Component | themes-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("default theme", async function (assert) {
    this.set("theme", Theme.create({ name: "Test", default: true }));

    await render(hbs`<ThemesListItem @theme={{this.theme}} />`);

    assert.expect(1);
    assert.strictEqual(count(".d-icon-check"), 1, "shows default theme icon");
  });

  test("pending updates", async function (assert) {
    this.set(
      "theme",
      Theme.create({ name: "Test", remote_theme: { commits_behind: 6 } })
    );

    await render(hbs`<ThemesListItem @theme={{this.theme}} />`);

    assert.expect(1);
    assert.strictEqual(count(".d-icon-sync"), 1, "shows pending update icon");
  });

  test("broken theme", async function (assert) {
    this.set(
      "theme",
      Theme.create({
        name: "Test",
        theme_fields: [{ name: "scss", type_id: 1, error: "something" }],
      })
    );

    await render(hbs`<ThemesListItem @theme={{this.theme}} />`);

    assert.expect(1);
    assert.strictEqual(
      count(".d-icon-exclamation-circle"),
      1,
      "shows broken theme icon"
    );
  });

  test("with children", async function (assert) {
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

    await render(hbs`<ThemesListItem @theme={{this.theme}} />`);

    assert.expect(2);
    assert.deepEqual(
      query(".components")
        .innerText.trim()
        .split(",")
        .map((n) => n.trim())
        .join(","),
      this.childrenList
        .splice(0, 4)
        .map((theme) => theme.get("name"))
        .join(","),
      "lists the first 4 children"
    );
    assert.deepEqual(
      query(".others-count").innerText.trim(),
      I18n.t("admin.customize.theme.and_x_more", { count: 1 }),
      "shows count of remaining children"
    );
  });
});
