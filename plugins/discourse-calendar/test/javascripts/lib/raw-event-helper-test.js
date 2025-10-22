import { module, test } from "qunit";
import { replaceRaw } from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";

module("Unit | Lib | raw-event-helper", function () {
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
  });
});
