import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";
import pretender from "discourse/tests/helpers/create-pretender";
import { settled } from "@ember/test-helpers";

function emojisReponse() {
  return { favorites: [{ name: "sad" }] };
}

module(
  "Discourse Chat | Unit | Service | chat-emoji-picker-manager",
  function (hooks) {
    hooks.beforeEach(function () {
      pretender.get("/chat/emojis.json", () => {
        return [200, {}, emojisReponse()];
      });

      this.manager = getOwner(this).lookup("service:chat-emoji-picker-manager");
    });

    hooks.afterEach(function () {
      this.manager.close();
    });

    test("addVisibleSections", async function (assert) {
      this.manager.addVisibleSections(["favorites", "objects"]);

      assert.deepEqual(this.manager.visibleSections, [
        "favorites",
        "smileys_&_emotion",
        "objects",
      ]);
    });

    test("sections", async function (assert) {
      assert.deepEqual(this.manager.sections, []);

      this.manager.open({});

      assert.deepEqual(this.manager.sections, []);

      await settled();

      assert.deepEqual(this.manager.sections, ["favorites"]);
    });

    test("open", async function (assert) {
      this.manager.open({ context: "chat-composer" });

      assert.ok(this.manager.loading);
      assert.ok(this.manager.picker);
      assert.strictEqual(this.manager.picker.context, "chat-composer");
      assert.deepEqual(this.manager.visibleSections, [
        "favorites",
        "smileys_&_emotion",
      ]);
      assert.strictEqual(this.manager.lastVisibleSection, "favorites");

      await settled();

      assert.deepEqual(this.manager.emojis, emojisReponse());
      assert.strictEqual(this.manager.loading, false);
    });

    test("closeExisting", async function (assert) {
      this.manager.open({ context: "channel-composer" });
      this.manager.addVisibleSections("objects");
      this.manager.lastVisibleSection = "objects";
      this.manager.open({ context: "thread-composer" });

      assert.strictEqual(
        this.manager.picker.context,
        "thread-composer",
        "it resets the picker to latest picker"
      );
      assert.deepEqual(
        this.manager.visibleSections,
        ["favorites", "smileys_&_emotion"],
        "it resets sections"
      );
      assert.strictEqual(
        this.manager.lastVisibleSection,
        "favorites",
        "it resets last visible section"
      );
    });

    test("close", async function (assert) {
      this.manager.open({ context: "channel-composer" });

      assert.ok(this.manager.picker);

      this.manager.addVisibleSections("objects");
      this.manager.lastVisibleSection = "objects";
      this.manager.close();

      assert.ok(this.manager.closing);
      assert.ok(this.manager.picker);

      await settled();

      assert.notOk(this.manager.picker);
      assert.notOk(this.manager.closing);
      assert.deepEqual(
        this.manager.visibleSections,
        ["favorites", "smileys_&_emotion"],
        "it resets visible sections"
      );
      assert.strictEqual(
        this.manager.lastVisibleSection,
        "favorites",
        "it resets last visible section"
      );
    });
  }
);
