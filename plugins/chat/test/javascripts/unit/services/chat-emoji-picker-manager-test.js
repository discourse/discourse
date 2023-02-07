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

    test("startFromMessageReactionList", async function (assert) {
      const callback = () => {};
      this.manager.startFromMessageReactionList({ id: 1 }, callback);

      assert.ok(this.manager.loading);
      assert.ok(this.manager.opened);
      assert.strictEqual(this.manager.context, "chat-message");
      assert.strictEqual(this.manager.callback, callback);
      assert.deepEqual(this.manager.visibleSections, [
        "favorites",
        "smileys_&_emotion",
      ]);
      assert.strictEqual(this.manager.lastVisibleSection, "favorites");

      await settled();

      assert.deepEqual(this.manager.emojis, emojisReponse());
      assert.strictEqual(this.manager.loading, false);
    });

    test("startFromMessageActions", async function (assert) {
      const callback = () => {};
      this.manager.startFromMessageReactionList({ id: 1 }, callback);

      assert.ok(this.manager.loading);
      assert.ok(this.manager.opened);
      assert.strictEqual(this.manager.context, "chat-message");
      assert.strictEqual(this.manager.callback, callback);
      assert.deepEqual(this.manager.visibleSections, [
        "favorites",
        "smileys_&_emotion",
      ]);
      assert.strictEqual(this.manager.lastVisibleSection, "favorites");

      await settled();

      assert.deepEqual(this.manager.emojis, emojisReponse());
      assert.strictEqual(this.manager.loading, false);
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

      this.manager.startFromComposer(() => {});

      assert.deepEqual(this.manager.sections, []);

      await settled();

      assert.deepEqual(this.manager.sections, ["favorites"]);
    });

    test("startFromComposer", async function (assert) {
      const callback = () => {};
      this.manager.startFromComposer(callback);

      assert.ok(this.manager.loading);
      assert.ok(this.manager.opened);
      assert.strictEqual(this.manager.context, "chat-composer");
      assert.strictEqual(this.manager.callback, callback);
      assert.deepEqual(this.manager.visibleSections, [
        "favorites",
        "smileys_&_emotion",
      ]);
      assert.strictEqual(this.manager.lastVisibleSection, "favorites");

      await settled();

      assert.deepEqual(this.manager.emojis, emojisReponse());
      assert.strictEqual(this.manager.loading, false);
    });

    test("startFromComposer with filter option", async function (assert) {
      const callback = () => {};
      this.manager.startFromComposer(callback, { filter: "foofilter" });
      await settled();

      assert.strictEqual(this.manager.initialFilter, "foofilter");
    });

    test("closeExisting", async function (assert) {
      const callback = () => {
        return;
      };

      this.manager.startFromComposer(() => {});
      this.manager.addVisibleSections("objects");
      this.manager.lastVisibleSection = "objects";
      this.manager.startFromComposer(callback);

      assert.strictEqual(
        this.manager.callback,
        callback,
        "it resets the callback to latest picker"
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

    test("didSelectEmoji", async function (assert) {
      let value;
      const callback = (emoji) => {
        value = emoji.name;
      };
      this.manager.startFromComposer(callback);
      this.manager.didSelectEmoji({ name: "joy" });

      assert.notOk(this.manager.callback);
      assert.strictEqual(value, "joy");

      await settled();

      assert.notOk(this.manager.opened, "it closes the picker after selection");
    });

    test("close", async function (assert) {
      this.manager.startFromComposer(() => {});

      assert.ok(this.manager.opened);
      assert.ok(this.manager.callback);

      this.manager.addVisibleSections("objects");
      this.manager.lastVisibleSection = "objects";
      this.manager.close();

      assert.notOk(this.manager.callback);
      assert.ok(this.manager.closing);
      assert.ok(this.manager.opened);

      await settled();

      assert.notOk(this.manager.opened);
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
