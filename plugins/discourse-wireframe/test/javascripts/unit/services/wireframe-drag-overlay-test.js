import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Discourse Wireframe | service:wireframe-drag-overlay",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.overlay = getOwner(this).lookup("service:wireframe-drag-overlay");
      // The kernel normally registers this in `enter()`; in isolation we
      // register a stub dispatcher that records what the overlay dispatches.
      this.dispatched = [];
      this.overlay.registerDispatcher((payload) => {
        this.dispatched.push(payload);
        return true;
      });
    });

    test("claimSlotInsert exposes the slot preview as a frozen projection", function (assert) {
      const descriptor = {
        geometry: { top: 1, left: 2, width: 3, height: 4 },
        kind: "insert",
        validity: "valid",
        label: "Drop here",
        dispatch: { action: "insertBlock", args: { x: 1 } },
      };
      this.overlay.claimSlotInsert(descriptor);

      const preview = this.overlay.slotPreview;
      assert.strictEqual(
        preview.previewKind,
        "insert",
        "the descriptor's kind is exposed as previewKind"
      );
      assert.strictEqual(preview.validity, "valid");
      assert.strictEqual(preview.label, "Drop here");
      assert.deepEqual(preview.geometry, descriptor.geometry);
    });

    test("slotPreview is frozen; mutating it cannot corrupt internal state", function (assert) {
      this.overlay.claimSlotInsert({
        geometry: { top: 1, left: 2, width: 3, height: 4 },
        kind: "insert",
        validity: "valid",
        label: "Drop here",
      });

      const preview = this.overlay.slotPreview;
      assert.true(Object.isFrozen(preview), "the projection is frozen");
      assert.true(Object.isFrozen(preview.geometry), "geometry is frozen too");

      // A consumer attempting to mutate the projection must not bleed into the
      // coordinator's state. (Frozen, so the writes are silently ignored.)
      try {
        preview.previewKind = "hacked";
        preview.geometry.left = 999;
      } catch {
        // strict mode throws on frozen writes — also acceptable.
      }

      const fresh = this.overlay.slotPreview;
      assert.strictEqual(fresh.previewKind, "insert", "previewKind intact");
      assert.strictEqual(fresh.geometry.left, 2, "geometry intact");
    });

    test("a null descriptor is an own-but-blank claim (owns the slot, shows nothing)", function (assert) {
      // A real slot preview, then a blank claim from a deeper target supersedes
      // it: the blank owns the slot, so nothing shows.
      this.overlay.claimSlotInsert({ kind: "insert", geometry: {} });
      assert.notStrictEqual(
        this.overlay.slotPreview,
        null,
        "real preview shows"
      );

      this.overlay.claimSlotInsert(null);
      assert.strictEqual(
        this.overlay.slotPreview,
        null,
        "the blank claim shows nothing"
      );
    });

    test("latest claim wins; an earlier (stale) release is a no-op", function (assert) {
      const identity = {
        blockKey: "image:1",
        argName: "image",
        isPassive: false,
      };
      const releaseSlot = this.overlay.claimSlotInsert({
        kind: "insert",
        geometry: {},
      });
      const releaseImage = this.overlay.claimImageArg(identity);

      assert.strictEqual(
        this.overlay.slotPreview,
        null,
        "the image-arg claim supersedes the slot preview"
      );
      assert.true(
        this.overlay.isActiveImageArg(identity),
        "the latest (image) claim is active"
      );

      releaseSlot();
      assert.true(
        this.overlay.isActiveImageArg(identity),
        "a superseded claim's release does not clear the active one"
      );

      releaseImage();
      assert.false(
        this.overlay.isActiveImageArg(identity),
        "the current release clears"
      );
    });

    test("isActiveImageArg matches by identity, including isPassive and variant", function (assert) {
      this.overlay.claimImageArg({
        blockKey: "image:1",
        argName: "image",
        isPassive: false,
        variant: "dark",
      });

      assert.true(
        this.overlay.isActiveImageArg({
          blockKey: "image:1",
          argName: "image",
          isPassive: false,
        })
      );
      assert.false(
        this.overlay.isActiveImageArg({
          blockKey: "image:1",
          argName: "image",
          isPassive: true,
        }),
        "isPassive must match"
      );
      assert.false(
        this.overlay.isActiveImageArg({
          blockKey: "image:2",
          argName: "image",
          isPassive: false,
        }),
        "blockKey must match"
      );
      assert.true(
        this.overlay.isActiveImageArg({
          blockKey: "image:1",
          argName: "image",
          isPassive: false,
          variant: "dark",
        }),
        "an explicit matching variant passes"
      );
      assert.false(
        this.overlay.isActiveImageArg({
          blockKey: "image:1",
          argName: "image",
          isPassive: false,
          variant: "light",
        }),
        "a non-matching variant fails"
      );
    });

    test("dispatch runs the slot-insert payload once, then clears", function (assert) {
      this.overlay.claimSlotInsert({
        kind: "insert",
        geometry: {},
        dispatch: { action: "insertBlock", args: { x: 1 } },
      });

      assert.true(this.overlay.dispatch(), "returns true when a payload ran");
      assert.deepEqual(this.dispatched, [
        { action: "insertBlock", args: { x: 1 } },
      ]);
      assert.strictEqual(
        this.overlay.slotPreview,
        null,
        "the slot is cleared after drop"
      );
      assert.false(
        this.overlay.dispatch(),
        "a second dispatch no-ops (sticky payload consumed)"
      );
    });

    test("dispatch no-ops for a blank claim", function (assert) {
      this.overlay.claimSlotInsert(null);
      assert.false(this.overlay.dispatch());
      assert.strictEqual(this.dispatched.length, 0);
    });

    test("clear resets the active overlay and the sticky dispatch", function (assert) {
      this.overlay.claimSlotInsert({
        kind: "insert",
        geometry: {},
        dispatch: { action: "insertBlock", args: {} },
      });
      this.overlay.clear();

      assert.strictEqual(this.overlay.slotPreview, null);
      assert.false(
        this.overlay.dispatch(),
        "no sticky dispatch survives clear"
      );
    });
  }
);
