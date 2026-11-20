import { setupTest } from "ember-qunit";
import { textReplace } from "pretty-text/text-replace";
import { module, test } from "qunit";

function buildState(...blocks) {
  return {
    tokens: blocks,
    md: {
      utils: {
        arrayReplaceAt(src, pos, newElements) {
          return [].concat(src.slice(0, pos), newElements, src.slice(pos + 1));
        },
      },
    },
  };
}

function inline(...children) {
  return { type: "inline", children };
}

const text = (content) => ({ type: "text", content });
const linkOpen = (info = "") => ({ type: "link_open", nesting: 1, info });
const linkClose = (info = "") => ({ type: "link_close", nesting: -1, info });
const html = (content) => ({ type: "html_inline", content });

function upcase(content) {
  return [text(content.toUpperCase())];
}

function contents(block) {
  return block.children.map((token) => token.content ?? token.type);
}

module("Unit | Pretty Text | Text Replace", function (hooks) {
  setupTest(hooks);

  test("textReplace swaps a text token for the callback's tokens", function (assert) {
    const block = inline(text("a"), text("b"));
    const state = buildState(block);
    const seen = [];

    textReplace(state, (content, callbackState) => {
      seen.push([content, callbackState === state]);
      return content === "b" ? [text("x"), text("y")] : null;
    });

    assert.deepEqual(contents(block), ["a", "x", "y"]);
    assert.deepEqual(
      seen,
      [
        ["b", true],
        ["a", true],
      ],
      "scans the tokens from the end and passes the state"
    );
  });

  test("textReplace skips blocks that aren't inline", function (assert) {
    const paragraph = { type: "paragraph_open", children: [text("a")] };
    const state = buildState(paragraph, inline(text("b")));

    textReplace(state, upcase);

    assert.strictEqual(paragraph.children[0].content, "a");
    assert.deepEqual(contents(state.tokens[1]), ["B"]);
  });

  test("textReplace skips text inside autolinks only", function (assert) {
    const block = inline(
      linkOpen("auto"),
      text("auto"),
      linkClose("auto"),
      linkOpen(),
      text("link"),
      linkClose(),
      text("plain")
    );

    textReplace(buildState(block), upcase);

    assert.deepEqual(contents(block), [
      "link_open",
      "auto",
      "link_close",
      "link_open",
      "LINK",
      "link_close",
      "PLAIN",
    ]);
  });

  test("textReplace skips text inside any link when asked", function (assert) {
    const block = inline(
      linkOpen(),
      text("link"),
      linkClose(),
      html('<a href="/x">'),
      text("html"),
      html("</a>"),
      text("plain")
    );

    textReplace(buildState(block), upcase, true);

    assert.deepEqual(contents(block), [
      "link_open",
      "link",
      "link_close",
      '<a href="/x">',
      "html",
      "</a>",
      "PLAIN",
    ]);
  });
});
