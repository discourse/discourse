import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import {
  registerUniversalDeprecationHandler,
  unregisterUniversalDeprecationHandler,
} from "discourse/lib/deprecated";
import ComboBox from "discourse/select-kit/components/combo-box";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const ID = "discourse.select-kit.implicit-mutation";
const FOO = { id: "foo", name: "foo", slug: "foo" };
const NO_TAGS = [];
const CONTENT = [
  { id: 1, name: "One" },
  { id: 2, name: "Two" },
];

class ComboBoxWithOwnChange extends ComboBox {
  onChange() {}
}

module(
  "Integration | Component | SelectKit | implicit mutation",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      disableRaiseOnDeprecation();
      sinon.stub(console, "warn");
      this.ids = [];
      this.handler = (message, options) => this.ids.push(options?.id);
      registerUniversalDeprecationHandler(this.handler);
    });

    hooks.afterEach(function () {
      unregisterUniversalDeprecationHandler(this.handler);
      enableRaiseOnDeprecation();
    });

    test("the deprecation is not silenced, so core and bundled plugin tests raise on it", function (assert) {
      assert.false(DeprecationWorkflow.shouldSilence(ID));
      assert.true(DeprecationWorkflow.shouldThrow(ID, true));
    });

    test("a select with no onChange deprecates writing the value back, and still writes it", async function (assert) {
      const held = tracked(1);

      await render(
        <template>
          <ComboBox @content={{CONTENT}} @value={{held.value}} />
        </template>
      );
      assert.false(this.ids.includes(ID), "rendering alone does not deprecate");

      await selectKit().expand();
      await selectKit().selectRowByValue(2);

      assert.true(this.ids.includes(ID), "the write deprecates");
      assert.strictEqual(held.value, 2, "the value is still written back");
    });

    test("a select with onChange does not deprecate", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <ComboBox @content={{CONTENT}} @onChange={{onChange}} @value={{1}} />
        </template>
      );
      await selectKit().expand();
      await selectKit().selectRowByValue(2);

      assert.true(onChange.calledWith(2));
      assert.false(this.ids.includes(ID));
    });

    test("a select with onSelect does not deprecate", async function (assert) {
      const onSelect = sinon.spy();

      await render(
        <template>
          <ComboBox @content={{CONTENT}} @onSelect={{onSelect}} @value={{1}} />
        </template>
      );
      await selectKit().expand();
      await selectKit().selectRowByValue(2);

      assert.true(onSelect.calledWith(2));
      assert.false(this.ids.includes(ID));
    });

    test("a class with its own onChange does not deprecate", async function (assert) {
      await render(
        <template>
          <ComboBoxWithOwnChange @content={{CONTENT}} @value={{1}} />
        </template>
      );
      await selectKit().expand();
      await selectKit().selectRowByValue(2);

      assert.false(this.ids.includes(ID));
    });

    test("a TagChooser with no onChange deprecates writing the tags back, and still writes them", async function (assert) {
      const tags = tracked([FOO]);

      await render(<template><TagChooser @tags={{tags.value}} /></template>);
      assert.false(this.ids.includes(ID), "rendering alone does not deprecate");

      await selectKit().expand();
      await selectKit().fillInFilter("mon");
      await selectKit().selectRowByName("monkey");

      assert.true(this.ids.includes(ID), "the write deprecates");
      assert.deepEqual(
        tags.value.map((tag) => tag.name),
        ["foo", "monkey"],
        "the tags are still written back"
      );
    });

    test("a TagChooser with onChange does not deprecate", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <TagChooser @onChange={{onChange}} @tags={{NO_TAGS}} />
        </template>
      );
      await selectKit().expand();
      await selectKit().fillInFilter("mon");
      await selectKit().selectRowByName("monkey");

      assert.true(onChange.calledOnce);
      assert.false(this.ids.includes(ID));
    });

    test("a MiniTagChooser with no onChange deprecates writing the value back, and still writes it", async function (assert) {
      const held = tracked([FOO]);

      await render(
        <template><MiniTagChooser @value={{held.value}} /></template>
      );
      assert.false(this.ids.includes(ID), "rendering alone does not deprecate");

      await selectKit().expand();
      await selectKit().fillInFilter("mon");
      await selectKit().selectRowByName("monkey");

      assert.true(this.ids.includes(ID), "the write deprecates");
      assert.deepEqual(
        held.value.map((tag) => tag.name),
        ["foo", "monkey"],
        "the value is still written back"
      );
    });

    test("a MiniTagChooser with onChange does not deprecate", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <MiniTagChooser @onChange={{onChange}} @value={{NO_TAGS}} />
        </template>
      );
      await selectKit().expand();
      await selectKit().fillInFilter("mon");
      await selectKit().selectRowByName("monkey");

      assert.true(onChange.calledOnce);
      assert.false(this.ids.includes(ID));
    });
  }
);
