import { module, test } from "qunit";
import {
  removeEvent,
  replaceRaw,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";

module("Unit | Lib | raw-event-helper", function () {
  test("removeEvent", function (assert) {
    assert.strictEqual(
      removeEvent('[event start="2024-01-01"]\nDescription\n[/event]'),
      "",
      "removes event with content"
    );

    assert.strictEqual(
      removeEvent(
        'Before\n[event start="2024-01-01"]\nContent\n[/event]\nAfter'
      ),
      "Before\n\nAfter",
      "preserves surrounding text"
    );

    assert.strictEqual(
      removeEvent('[event start="2024-01-01"]\n[/event]'),
      "",
      "removes event without content"
    );
  });

  test("replaceRaw", function (assert) {
    const raw = 'Some text \n[event param1="va]lue1"]\n[/event]\n more text';
    const params = {
      param1: "newValue1",
      param2: "value2",
    };

    assert.strictEqual(
      replaceRaw(params, raw),
      'Some text \n[event param1="newValue1" param2="value2"]\n[/event]\n more text',
      "updates existing parameters and adds new ones"
    );

    assert.false(
      replaceRaw(params, "No event tag here"),
      "returns false when no event tag is found"
    );

    assert.strictEqual(
      replaceRaw({ foo: 'bar"quoted' }, '[event original="value"]\n[/event]'),
      '[event foo="barquoted"]\n[/event]',
      "escapes double quotes in parameter values"
    );

    assert.strictEqual(
      replaceRaw({}, '[event param1="value1"]\n[/event]'),
      "[event ]\n[/event]",
      "handles empty params object"
    );

    assert.strictEqual(
      replaceRaw(
        { name: "", location: "Paris" },
        '[event original="value"]\n[/event]'
      ),
      '[event location="Paris"]\n[/event]',
      "omits empty name parameter"
    );

    assert.strictEqual(
      replaceRaw(
        { name: "   ", location: "Berlin" },
        '[event original="value"]\n[/event]'
      ),
      '[event location="Berlin"]\n[/event]',
      "omits whitespace-only name parameter"
    );
  });
});
