import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

const STORAGE_KEY = "page-shell-panels";

module("Unit | Service | page shell", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:key-value-store");
    this.shell = () => getOwner(this).lookup("service:page-shell");
    this.stored = () => this.store.getObject(STORAGE_KEY);
    this.input = (name, value, type = "change") =>
      this.shell().change({ type, target: { name, value: String(value) } });
  });

  test("uses defaults without saved preferences", function (assert) {
    const shell = this.shell();

    assert.strictEqual(shell.width, "full", "the shell starts at full width");
    assert.strictEqual(shell.navigation, "open");
    assert.strictEqual(shell.context, "open");
    assert.strictEqual(shell.navigationWidth, 260);
    assert.strictEqual(shell.contextWidth, 300);
    assert.strictEqual(this.stored(), undefined, "loading writes nothing");
  });

  test("imports the legacy hidden sidebar as a rail when nothing is saved", function (assert) {
    this.store.setItem("sidebar-hidden", "true");

    assert.strictEqual(this.shell().navigation, "rail");
    assert.strictEqual(this.stored(), undefined, "loading writes nothing");
  });

  test("saved preferences win over the legacy hidden sidebar", function (assert) {
    this.store.setItem("sidebar-hidden", "true");
    this.store.setObject({
      key: STORAGE_KEY,
      value: {
        version: 1,
        navigation: { mode: "rail", width: 320 },
        context: { mode: "hidden", width: 640 },
      },
    });
    const shell = this.shell();

    assert.strictEqual(shell.navigation, "rail");
    assert.strictEqual(shell.navigationWidth, 320);
    assert.strictEqual(shell.context, "hidden");
    assert.strictEqual(shell.contextWidth, 640);
  });

  test("malformed fields fall back individually and widths are clamped", function (assert) {
    this.store.setObject({
      key: STORAGE_KEY,
      value: {
        version: 1,
        navigation: { mode: "docked", width: 9999 },
        context: { mode: "rail", width: "wide" },
      },
    });
    const shell = this.shell();

    assert.strictEqual(shell.navigation, "open");
    assert.strictEqual(shell.navigationWidth, 400);
    assert.strictEqual(shell.context, "open");
    assert.strictEqual(shell.contextWidth, 300);
  });

  test("invalid JSON uses defaults", function (assert) {
    this.store.setItem(STORAGE_KEY, "{not json");
    assert.strictEqual(this.shell().navigation, "open");
  });

  test("an unknown version is ignored", function (assert) {
    this.store.setObject({
      key: STORAGE_KEY,
      value: { version: 2, navigation: { mode: "rail", width: 320 } },
    });
    assert.strictEqual(this.shell().navigation, "open");
    assert.strictEqual(this.shell().navigationWidth, 260);
  });

  test("width changes save once when committed", function (assert) {
    this.input("navigationWidth", 300, "input");
    this.input("navigationWidth", 340, "input");
    assert.strictEqual(this.shell().navigationWidth, 340);
    assert.strictEqual(this.stored(), undefined, "live input does not save");

    this.input("navigationWidth", 340);
    assert.deepEqual(this.stored(), {
      version: 1,
      navigation: { mode: "open", width: 340 },
      context: { mode: "open", width: 300 },
    });
  });

  test("site policy controls are not saved", function (assert) {
    this.input("width", "centered");
    this.input("contextPosition", "end");
    this.input("footer", "row");
    assert.strictEqual(this.stored(), undefined);
  });

  test("a saved hidden Navigation preference loads as a rail", function (assert) {
    this.store.setObject({
      key: STORAGE_KEY,
      value: {
        version: 1,
        navigation: { mode: "hidden", width: 320 },
      },
    });

    assert.strictEqual(this.shell().navigation, "rail");
    assert.strictEqual(this.shell().navigationWidth, 320);
  });

  test("the navigation toggle switches between open and rail", function (assert) {
    this.shell().toggleNavigation();
    assert.strictEqual(this.stored().navigation.mode, "rail");
    assert.strictEqual(this.store.getItem("sidebar-hidden"), "true");

    this.shell().toggleNavigation();
    assert.strictEqual(this.stored().navigation.mode, "open");
    assert.strictEqual(this.store.getItem("sidebar-hidden"), undefined);
  });

  test("clamping context to the available space keeps the saved width", function (assert) {
    const shell = this.shell();
    shell.contextMaxWidth = 1000;
    this.input("contextWidth", 800);
    shell.contextMaxWidth = 400;

    assert.strictEqual(shell.effectiveContextWidth, 400);
    assert.strictEqual(shell.contextWidth, 800);
    assert.strictEqual(this.stored().context.width, 800);
  });
});
