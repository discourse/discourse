import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | interface-color", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.session = getOwner(this).lookup("service:session");
    this.subject = getOwner(this).lookup("service:interface-color");
  });

  test("darkMediaQuery never matches without a dark scheme", function (assert) {
    this.session.darkModeAvailable = false;
    this.session.defaultColorSchemeIsDark = false;

    assert.strictEqual(this.subject.darkMediaQuery, "none");
  });

  test("darkMediaQuery always matches with a dark default scheme", function (assert) {
    this.session.darkModeAvailable = false;
    this.session.defaultColorSchemeIsDark = true;

    assert.strictEqual(this.subject.darkMediaQuery, "all");
  });

  test("darkMediaQuery follows the forced mode, else the OS", function (assert) {
    this.session.darkModeAvailable = true;
    this.session.defaultColorSchemeIsDark = false;

    this.subject.colorMode = "dark";
    assert.strictEqual(this.subject.darkMediaQuery, "all");

    this.subject.colorMode = "light";
    assert.strictEqual(this.subject.darkMediaQuery, "none");

    this.subject.colorMode = "auto";
    assert.strictEqual(
      this.subject.darkMediaQuery,
      "(prefers-color-scheme: dark)"
    );
  });
});
