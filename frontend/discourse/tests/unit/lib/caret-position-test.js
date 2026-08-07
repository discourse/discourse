import { module, test } from "qunit";
import { caretCoordinates } from "discourse/lib/caret-position";

function withTextarea(css, callback) {
  const textarea = document.createElement("textarea");
  Object.assign(textarea.style, {
    position: "absolute",
    top: "0",
    left: "0",
    boxSizing: "content-box",
    border: "1px solid black",
    padding: "5px",
    width: "300px",
    height: "150px",
    fontFamily: "monospace",
    fontSize: "14px",
    lineHeight: "18px",
    letterSpacing: "normal",
    ...css,
  });
  document.body.appendChild(textarea);
  try {
    return callback(textarea);
  } finally {
    textarea.remove();
  }
}

module("Unit | Lib | caret-position", function () {
  test("returns finite coordinates across a range of inputs", function (assert) {
    const cases = [
      { value: "", pos: 0 },
      { value: "a", pos: 1 },
      { value: "hello world", pos: 5 },
      { value: "line one\nline two\nline three", pos: 20 },
      { value: "trailing spaces   ", pos: 18 },
      { value: "html <b> & </b> chars", pos: 8 },
      { value: "café résumé 😀 🎉", pos: 7 },
      { value: "x".repeat(400), pos: 250 },
    ];

    for (const { value, pos } of cases) {
      withTextarea({}, (textarea) => {
        textarea.value = value;
        const { left, top } = caretCoordinates(textarea, { pos });

        assert.true(
          Number.isFinite(left),
          `left is a finite number for ${JSON.stringify(value)}@${pos}`
        );
        assert.true(
          Number.isFinite(top),
          `top is a finite number for ${JSON.stringify(value)}@${pos}`
        );
      });
    }
  });

  test("caret moves rightward as its position advances along a line", function (assert) {
    withTextarea({}, (textarea) => {
      textarea.value = "hello world";

      const positions = [0, 3, 6, 9];
      const coords = positions.map((pos) =>
        caretCoordinates(textarea, { pos })
      );

      for (let i = 1; i < coords.length; i++) {
        assert.true(
          coords[i].left > coords[i - 1].left,
          `left increases from pos ${positions[i - 1]} to ${positions[i]}`
        );
        assert.strictEqual(
          coords[i].top,
          coords[0].top,
          `top is unchanged within the same line at pos ${positions[i]}`
        );
      }
    });
  });

  test("caret drops down and returns to the left margin across lines", function (assert) {
    withTextarea({}, (textarea) => {
      // indices: a a a a a \n b b
      textarea.value = "aaaaa\nbb";

      const endOfLine1 = caretCoordinates(textarea, { pos: 5 });
      const startOfLine2 = caretCoordinates(textarea, { pos: 6 });

      assert.true(
        startOfLine2.top > endOfLine1.top,
        "caret on line 2 is below caret on line 1"
      );
      assert.true(
        startOfLine2.left < endOfLine1.left,
        "caret at the start of line 2 is left of the end of line 1"
      );
    });
  });

  test("a soft-wrapped long line pushes the caret down", function (assert) {
    withTextarea({ width: "120px" }, (textarea) => {
      textarea.value =
        "one two three four five six seven eight nine ten eleven twelve";

      const start = caretCoordinates(textarea, { pos: 0 });
      const end = caretCoordinates(textarea, { pos: textarea.value.length });

      assert.true(
        end.top > start.top,
        "caret at the end of a wrapped line sits below the start"
      );
    });
  });

  test("falls back to selectionStart when no pos is given", function (assert) {
    withTextarea({}, (textarea) => {
      textarea.value = "hello world";
      textarea.setSelectionRange(6, 6);

      const fromSelection = caretCoordinates(textarea);
      const fromExplicitPos = caretCoordinates(textarea, { pos: 6 });

      assert.strictEqual(
        fromSelection.left,
        fromExplicitPos.left,
        "left matches the explicit position"
      );
      assert.strictEqual(
        fromSelection.top,
        fromExplicitPos.top,
        "top matches the explicit position"
      );
    });
  });

  test("accounts for a virtual character from options.key", function (assert) {
    withTextarea({}, (textarea) => {
      textarea.value = "ab";

      const { left, top } = caretCoordinates(textarea, { pos: 1, key: "X" });

      assert.true(Number.isFinite(left), "left is finite with a virtual key");
      assert.true(Number.isFinite(top), "top is finite with a virtual key");
    });
  });

  test("returns finite coordinates in RTL", function (assert) {
    document.documentElement.classList.add("rtl");
    try {
      withTextarea({}, (textarea) => {
        textarea.value = "مرحبا بالعالم\nsecond line";

        const { left, top } = caretCoordinates(textarea, { pos: 4 });

        assert.true(Number.isFinite(left), "left is finite in RTL");
        assert.true(Number.isFinite(top), "top is finite in RTL");
      });
    } finally {
      document.documentElement.classList.remove("rtl");
    }
  });
});
