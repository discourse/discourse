import componentTest from "helpers/component-test";
import Theme from "admin/models/theme";

moduleForComponent("themes-list-item", { integration: true });

componentTest("default theme", {
  template: "{{themes-list-item theme=theme}}",
  beforeEach() {
    this.set("theme", Theme.create({ name: "Test", default: true }));
  },

  test(assert) {
    assert.expect(1);
    assert.equal(find(".d-icon-check").length, 1, "shows default theme icon");
  }
});

componentTest("pending updates", {
  template: "{{themes-list-item theme=theme}}",
  beforeEach() {
    this.set(
      "theme",
      Theme.create({ name: "Test", remote_theme: { commits_behind: 6 } })
    );
  },

  test(assert) {
    assert.expect(1);
    assert.equal(find(".d-icon-sync").length, 1, "shows pending update icon");
  }
});

componentTest("broken theme", {
  template: "{{themes-list-item theme=theme}}",
  beforeEach() {
    this.set(
      "theme",
      Theme.create({
        name: "Test",
        theme_fields: [{ name: "scss", type_id: 1, error: "something" }]
      })
    );
  },

  test(assert) {
    assert.expect(1);
    assert.equal(
      find(".d-icon-exclamation-circle").length,
      1,
      "shows broken theme icon"
    );
  }
});

const childrenList = [1, 2, 3, 4, 5].map(num =>
  Theme.create({ name: `Child ${num}`, component: true })
);

componentTest("with children", {
  template: "{{themes-list-item theme=theme}}",

  beforeEach() {
    this.set(
      "theme",
      Theme.create({ name: "Test", childThemes: childrenList, default: true })
    );
  },

  test(assert) {
    assert.expect(2);
    assert.deepEqual(
      find(".components")
        .text()
        .trim()
        .split(",")
        .map(n => n.trim())
        .join(","),
      childrenList
        .splice(0, 4)
        .map(theme => theme.get("name"))
        .join(","),
      "lists the first 4 children"
    );
    assert.deepEqual(
      find(".others-count")
        .text()
        .trim(),
      I18n.t("admin.customize.theme.and_x_more", { count: 1 }),
      "shows count of remaining children"
    );
  }
});
