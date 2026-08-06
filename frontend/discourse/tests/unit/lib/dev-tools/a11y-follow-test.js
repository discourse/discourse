import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as an assertion failing.
import * as follow from "discourse/static/dev-tools/a11y/follow";

/**
 * Oracle for the follow decision (unit 2d).
 *
 * One question, asked on every scroll: is the reader still at the bottom. Getting
 * it wrong in either direction is a real defect rather than a rough edge — too
 * strict and the panel reports itself detached while the reader is visibly pinned,
 * so it stops following during exactly the live capture it exists for; too loose
 * and it yanks someone away from the history they are reading.
 *
 * Kept as a pure function of three numbers so it can be pinned without a layout:
 * a rendering test cannot rely on the panel's stylesheet being loaded, so the box
 * it would have to measure is not reliably there.
 */
module("Unit | Lib | dev-tools | a11y-follow", function (hooks) {
  setupTest(hooks);

  /** A box scrolled `remainder` pixels short of its bottom. */
  function shortBy(remainder) {
    return {
      scrollTop: 1000 - remainder,
      scrollHeight: 2000,
      clientHeight: 1000,
    };
  }

  test("a box scrolled exactly to its bottom is at the bottom", function (assert) {
    assert.true(follow.isAtBottom(shortBy(0)));
  });

  /*
   * The reason the tolerance exists. Fractional device pixel ratios, subpixel row
   * heights and browser rounding all leave a remainder, so an equality test
   * against zero reports "detached" while nothing has moved.
   */
  test("a fractional remainder is still the bottom", function (assert) {
    assert.true(
      follow.isAtBottom(shortBy(0.5)),
      "half a pixel is not scrolling"
    );
    assert.true(
      follow.isAtBottom(shortBy(follow.BOTTOM_TOLERANCE_PX)),
      "and the tolerance itself counts as at the bottom"
    );
  });

  test("scrolled up beyond the tolerance is not the bottom", function (assert) {
    assert.false(
      follow.isAtBottom(shortBy(follow.BOTTOM_TOLERANCE_PX + 1)),
      "someone reading history is detached"
    );
    assert.false(
      follow.isAtBottom(shortBy(600)),
      "and so is someone well up it"
    );
  });

  /*
   * Nothing overflows, so there is no bottom to be away from. Reporting this as
   * detached would show a jump-to-latest control on a list that is entirely
   * visible, pointing at rows the reader is already looking at.
   */
  test("a box whose content fits is always at the bottom", function (assert) {
    assert.true(
      follow.isAtBottom({
        scrollTop: 0,
        scrollHeight: 300,
        clientHeight: 300,
      })
    );
  });

  // The tolerance is a parameter so the panel can state its own, and so this
  // oracle can pin the boundary without depending on the default's value.
  test("the tolerance is the caller's to choose", function (assert) {
    assert.true(
      follow.isAtBottom(shortBy(20), 25),
      "a generous tolerance holds"
    );
    assert.false(follow.isAtBottom(shortBy(20), 5), "a tight one does not");
  });

  test("the default tolerance is a small positive number of pixels", function (assert) {
    assert.true(Number.isFinite(follow.BOTTOM_TOLERANCE_PX), "it is a number");
    assert.true(
      follow.BOTTOM_TOLERANCE_PX > 0,
      "greater than zero, or it is an equality test with extra steps"
    );
  });
});
