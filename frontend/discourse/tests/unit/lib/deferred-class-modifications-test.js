import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  applyDeferredClassModifications,
  deferClassModification,
  lazyClassFor,
  registerModuleForModifyClass,
} from "discourse/lib/deferred-class-modifications";

module("Unit | Lib | deferred-class-modifications", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    applyDeferredClassModifications();
  });

  test("keys a component by the name the resolver asks for", function (assert) {
    class Icon {}
    registerModuleForModifyClass("chat/header/icon", Icon);

    assert.strictEqual(lazyClassFor("component:chat/header/icon").class, Icon);
    assert.strictEqual(lazyClassFor("component:missing"), null);
  });

  test("applies a modification that arrived before the module", function (assert) {
    class Header {}
    let applied = 0;

    deferClassModification("component:chat-header", () => applied++);
    assert.strictEqual(applied, 0, "waits for the module");

    registerModuleForModifyClass("chat-header", Header);
    assert.strictEqual(applied, 1);

    registerModuleForModifyClass("chat-header", Header);
    assert.strictEqual(applied, 1);
  });

  test("leaves modifications for other names alone", function (assert) {
    let applied = 0;
    deferClassModification("component:not-this-one", () => applied++);

    registerModuleForModifyClass("chat-header", class {});
    assert.strictEqual(applied, 0);

    applyDeferredClassModifications();
    assert.strictEqual(applied, 1);
  });
});
