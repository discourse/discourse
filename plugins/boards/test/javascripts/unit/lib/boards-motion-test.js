import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  animateCardReorder,
  boardsMotionEnabled,
  captureCardRects,
  KANBAN_MOTION_EASING,
  KANBAN_REORDER_DURATION,
} from "discourse/plugins/boards/discourse/lib/boards-motion";

function createCard(cardId) {
  const card = document.createElement("div");
  card.className = "discourse-boards-card";
  card.dataset.cardId = String(cardId);
  return card;
}

module("Boards | Unit | Lib | boards-motion", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalMatchMedia = window.matchMedia;
    this.container = document.createElement("div");
    document.body.append(this.container);
  });

  hooks.afterEach(function () {
    window.matchMedia = this.originalMatchMedia;
    this.container.remove();
  });

  test("boardsMotionEnabled respects reduced motion", function (assert) {
    window.matchMedia = () => ({ matches: true });
    assert.false(boardsMotionEnabled());

    window.matchMedia = () => ({ matches: false });
    assert.true(boardsMotionEnabled());
  });

  test("captureCardRects skips excluded cards", function (assert) {
    const firstCard = createCard(1);
    firstCard.getBoundingClientRect = () => ({ left: 16, top: 24 });

    const secondCard = createCard(2);
    secondCard.getBoundingClientRect = () => ({ left: 32, top: 48 });

    this.container.append(firstCard, secondCard);

    const rects = captureCardRects(this.container, { skipCardIds: [2] });

    assert.deepEqual(rects.get("1"), { left: 16, top: 24 });
    assert.false(rects.has("2"));
  });

  test("animateCardReorder animates cards from the previous visual position", function (assert) {
    window.matchMedia = () => ({ matches: false });

    const card = createCard(1);
    let frames;
    let options;

    card.getBoundingClientRect = () => ({ left: 12, top: 72 });
    card.animate = (newFrames, newOptions) => {
      frames = newFrames;
      options = newOptions;

      return {
        cancel() {},
        oncancel: null,
        onfinish: null,
      };
    };

    this.container.append(card);

    animateCardReorder(this.container, new Map([["1", { left: 12, top: 24 }]]));

    assert.deepEqual(frames, [
      { transform: "translate3d(0px, -48px, 0)" },
      { transform: "translate3d(0, 0, 0)" },
    ]);
    assert.deepEqual(options, {
      duration: KANBAN_REORDER_DURATION,
      easing: KANBAN_MOTION_EASING,
    });
  });

  test("animateCardReorder skips cards when Element.animate is unavailable", function (assert) {
    window.matchMedia = () => ({ matches: false });

    const card = createCard(1);
    card.getBoundingClientRect = () => ({ left: 12, top: 72 });

    this.container.append(card);

    animateCardReorder(this.container, new Map([["1", { left: 12, top: 24 }]]));

    assert.strictEqual(
      card.style.transform,
      "",
      "it skips the animation when animations are unsupported"
    );
  });
});
