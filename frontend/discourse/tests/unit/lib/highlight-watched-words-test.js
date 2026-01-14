import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";

module("Unit | Utility | highlight-watched-words", function (hooks) {
  setupTest(hooks);

  test("no text", function (assert) {
    const text = null;
    const reviewable = {
      reviewable_scores: [
        {
          reason_type: "watched_word",
          reason_data: ["some text", "is", "word not in this text"],
        },
      ],
    };
    const highlighted = highlightWatchedWords(text, reviewable);
    assert.strictEqual(highlighted, null, "it should return the original text");
  });

  test("no reviewable", function (assert) {
    const text = "This is some text to highlight";
    const reviewable = null;
    const highlighted = highlightWatchedWords(text, reviewable);
    assert.strictEqual(
      highlighted.toString(),
      "This is some text to highlight",
      "it should return the original text"
    );
  });

  test("no reviewable scores", function (assert) {
    const text = "This is some text to highlight";
    const reviewable = {
      reviewable_scores: null,
    };
    const highlighted = highlightWatchedWords(text, reviewable);
    assert.strictEqual(
      highlighted.toString(),
      "This is some text to highlight",
      "it should return the original text"
    );
  });

  test("no watched words", function (assert) {
    const text = "This is some text to highlight";
    const reviewable = {
      reviewable_scores: [
        {
          reason_type: "watched_word",
          reason_data: [],
        },
      ],
    };
    const highlighted = highlightWatchedWords(text, reviewable);
    assert.strictEqual(
      highlighted.toString(),
      "This is some text to highlight",
      "it should return the original text"
    );
  });

  test("highlighting text", function (assert) {
    const text = "This is some text to highlight";
    const reviewable = {
      reviewable_scores: [
        {
          reason_type: "watched_word",
          reason_data: ["some text", "is", "word not in this text"],
        },
      ],
    };

    const highlighted = highlightWatchedWords(text, reviewable);

    assert.strictEqual(
      highlighted.toString(),
      'This <mark class="watched-word-highlight">is</mark> <mark class="watched-word-highlight">some text</mark> to highlight',
      "it should highlight the term correctly"
    );
  });

  test("highlighting unicode text", function (assert) {
    const text = "This is some தமிழ் & русский text to highlight";

    const reviewable = {
      reviewable_scores: [
        {
          reason_type: "watched_word",
          reason_data: ["தமிழ் & русский", "highlight", "this"],
        },
      ],
    };

    const highlighted = highlightWatchedWords(text, reviewable);

    assert.strictEqual(
      highlighted.toString(),
      '<mark class="watched-word-highlight">This</mark> is some <mark class="watched-word-highlight">தமிழ் & русский</mark> text to <mark class="watched-word-highlight">highlight</mark>',
      "it should highlight the term correctly"
    );
  });
});
