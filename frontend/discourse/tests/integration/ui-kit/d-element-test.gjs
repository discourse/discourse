import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dElement from "discourse/ui-kit/helpers/d-element";

module("Integration | ui-kit | dElement", function (hooks) {
  setupRenderingTest(hooks);

  test("a shortcut tag resolves to its dedicated wrapper", async function (assert) {
    const Tag = dElement("ul");

    await render(
      <template>
        <Tag class="probe">item</Tag>
      </template>
    );

    assert.dom(".probe").hasTagName("ul");
  });

  test("an unlisted tag falls back to a wrapper for that tag", async function (assert) {
    const Tag = dElement("section");

    await render(
      <template>
        <Tag class="probe">item</Tag>
      </template>
    );

    assert.dom(".probe").hasTagName("section");
  });

  // The shortcut table is a plain object, so a bare property read reaches
  // `Object.prototype`. A tag name that collides with an inherited member must
  // still take the fallback path rather than resolving to that member.
  //
  // Asserted on the resolved value rather than by rendering it: an inherited
  // member is not a component, so rendering one throws past the test and takes
  // the rest of the run with it.
  test("a tag named after an inherited Object member takes the fallback", function (assert) {
    for (const tagName of [
      "constructor",
      "toString",
      "valueOf",
      "hasOwnProperty",
    ]) {
      assert.notStrictEqual(
        dElement(tagName),
        Object.prototype[tagName],
        `dElement("${tagName}") does not resolve to the inherited member`
      );
    }

    assert.strictEqual(
      dElement("constructor"),
      dElement("constructor"),
      "and the fallback for it is still cached by tag name"
    );
  });
});
