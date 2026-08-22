import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import bbcodeBlockInputRule from "discourse/plugins/discourse-events/discourse/lib/bbcode-block-input-rule";

// stands in for the editor: the rule matches the node it built by identity,
// so the fake schema and the fake parse result share one node type
function setup(tag, nodeName, { match, parsesTo = nodeName } = {}) {
  const nodeType = { name: nodeName };
  const otherType = { name: "paragraph" };
  const built = { markdown: null };

  const rule = bbcodeBlockInputRule(
    tag,
    nodeName,
    match
  )({
    utils: {
      convertFromMarkdown: (markdown) => {
        built.markdown = markdown;
        return {
          content: {
            firstChild: {
              type: parsesTo === nodeName ? nodeType : otherType,
            },
          },
        };
      },
    },
  });

  const state = {
    schema: { nodes: { [nodeName]: nodeType } },
    tr: {
      replaceWith: (start, end, node) => ({ start, end, node }),
    },
  };

  const run = (text) => {
    const matched = text.match(rule.match);
    return matched ? rule.handler(state, matched, 0, text.length) : null;
  };

  return { rule, built, run, nodeType };
}

module("Unit | Lib | bbcode-block-input-rule", function (hooks) {
  setupTest(hooks);

  test("converts a bare tag", function (assert) {
    const { built, run, nodeType } = setup("calendar", "calendar");

    const result = run("[calendar]");

    assert.strictEqual(built.markdown, "[calendar]\n[/calendar]");
    assert.strictEqual(result.node.type, nodeType);
  });

  test("keeps the typed attributes", function (assert) {
    const { built, run } = setup("calendar", "calendar");

    run("[calendar type=static]");

    assert.strictEqual(built.markdown, "[calendar type=static]\n[/calendar]");
  });

  test("ignores a tag that only shares a prefix", function (assert) {
    const { rule } = setup("calendar", "calendar");

    assert.strictEqual("[calendars]".match(rule.match), null);
    assert.strictEqual("[calendar-view]".match(rule.match), null);
  });

  test("leaves the text alone when the markdown is not the node", function (assert) {
    const { run } = setup("calendar", "calendar", { parsesTo: "paragraph" });

    assert.strictEqual(run("[calendar]"), null);
  });

  test("a custom match can require an attribute", function (assert) {
    const { rule } = setup("timezones", "group_timezones", {
      match: /^\[timezones\s([^\]]*group=[^\]]*)]$/,
    });

    assert.strictEqual("[timezones]".match(rule.match), null);
    assert.true(!!"[timezones group=admins]".match(rule.match));
  });
});
