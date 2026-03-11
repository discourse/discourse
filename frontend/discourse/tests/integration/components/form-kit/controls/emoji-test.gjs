import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Emoji",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/emojis.json", () =>
        response(emojisFixtures["/emojis.json"])
      );
      pretender.get("/emojis/search-aliases.json", () => response([]));

      this.emojiStore = this.container.lookup("service:emoji-store");
    });

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Emoji />
            </form.Field>
          </Form>
        </template>
      );

      await click(".btn-emoji");
      await emojiPicker(".emoji-picker").select("grinning");
      await formKit().submit();

      assert.strictEqual(data.foo, "grinning");
    });
  }
);
