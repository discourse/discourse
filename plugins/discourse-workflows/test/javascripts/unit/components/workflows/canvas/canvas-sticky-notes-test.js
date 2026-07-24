import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  buildStickyNoteTranslateHandler,
  computeStickyNoteRects,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-sticky-notes";

module("Unit | Canvas Sticky Notes", function (hooks) {
  setupTest(hooks);

  module("computeStickyNoteRects", function () {
    test("maps sticky notes to position/size rects", function (assert) {
      const notes = [
        {
          clientId: "sn1",
          position: { x: 10, y: 20 },
          size: { width: 100, height: 50 },
        },
        {
          clientId: "sn2",
          position: { x: 30, y: 40 },
          size: { width: 200, height: 150 },
        },
      ];

      const rects = computeStickyNoteRects(notes);

      assert.deepEqual(rects, [
        { clientId: "sn1", x: 10, y: 20, width: 100, height: 50 },
        { clientId: "sn2", x: 30, y: 40, width: 200, height: 150 },
      ]);
    });

    test("returns empty array for null/undefined input", function (assert) {
      assert.deepEqual(computeStickyNoteRects(null), []);
      assert.deepEqual(computeStickyNoteRects(undefined), []);
    });

    test("returns empty array for empty list", function (assert) {
      assert.deepEqual(computeStickyNoteRects([]), []);
    });
  });

  module("buildStickyNoteTranslateHandler", function () {
    test("applies delta to matching note position", function (assert) {
      const notes = [
        {
          clientId: "sn1",
          position: { x: 100, y: 200 },
        },
        {
          clientId: "sn2",
          position: { x: 50, y: 75 },
        },
      ];

      let movedId, movedPosition;
      const handler = buildStickyNoteTranslateHandler(notes, (id, pos) => {
        movedId = id;
        movedPosition = pos;
      });

      handler("sn1", 10, -5);

      assert.strictEqual(movedId, "sn1");
      assert.deepEqual(movedPosition, { x: 110, y: 195 });
    });

    test("uses latest sticky notes from a getter", function (assert) {
      let notes = [{ clientId: "sn1", position: { x: 0, y: 0 } }];
      let movedPosition;
      const handler = buildStickyNoteTranslateHandler(
        () => notes,
        (id, pos) => {
          movedPosition = pos;
        }
      );

      notes = [{ clientId: "sn1", position: { x: 20, y: 30 } }];
      handler("sn1", 5, 10);

      assert.deepEqual(movedPosition, { x: 25, y: 40 });
    });

    test("does nothing when note is not found", function (assert) {
      const notes = [{ clientId: "sn1", position: { x: 0, y: 0 } }];
      let called = false;
      const handler = buildStickyNoteTranslateHandler(notes, () => {
        called = true;
      });

      handler("nonexistent", 10, 10);

      assert.false(called);
    });

    test("does nothing when onMove is not provided", function (assert) {
      const notes = [{ clientId: "sn1", position: { x: 0, y: 0 } }];
      const handler = buildStickyNoteTranslateHandler(notes, undefined);

      handler("sn1", 10, 10);

      assert.true(true, "no error thrown");
    });

    test("handles null stickyNotes list", function (assert) {
      let called = false;
      const handler = buildStickyNoteTranslateHandler(null, () => {
        called = true;
      });

      handler("sn1", 10, 10);

      assert.false(called);
    });
  });
});
