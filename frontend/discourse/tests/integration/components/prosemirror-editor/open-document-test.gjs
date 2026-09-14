import { tracked } from "@glimmer/tracking";
import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DEditor from "discourse/ui-kit/d-editor";

// Mocked by create-pretender for /onebox.
const ONEBOX_URL = "http://www.example.com/has-title.html";

async function openRichEditor(markdown) {
  const state = new (class {
    @tracked value = markdown;
    changes = [];
    onChange = (event) => this.changes.push(event.target.value);
  })();

  await render(
    <template>
      <DEditor
        @change={{state.onChange}}
        @processPreview={{false}}
        @value={{state.value}}
      />
    </template>
  );

  await click(".composer-toggle-switch");
  await waitFor(".ProseMirror");
  await settled();

  return state;
}

module(
  "Integration | Component | prosemirror-editor - opening a document",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/hashtags", () =>
        response({
          categories: [
            { type: "category", ref: "product", style_type: "square", id: 2 },
          ],
        })
      );

      pretender.get("/composer/mentions", () =>
        response({
          users: [],
          user_reasons: {},
          groups: {},
          group_reasons: {},
          max_users_notified_per_group_mention: 100,
        })
      );
    });

    test("resolving a hashtag doesn't change the value", async function (assert) {
      const state = await openRichEditor("#product");

      assert
        .dom("a.hashtag-cooked[data-processed='true']")
        .exists("resolves the hashtag");
      assert.deepEqual(state.changes, [], "doesn't report a value change");
    });

    test("invalidating a mention doesn't change the value", async function (assert) {
      const state = await openRichEditor("Hello @invalid");

      assert.dom("a.mention").doesNotExist("drops the invalid mention");
      assert.deepEqual(state.changes, [], "doesn't report a value change");
    });

    test("loading a onebox doesn't change the value", async function (assert) {
      // not last: the cursor lands there on open, holding back the preview
      const state = await openRichEditor(`${ONEBOX_URL}\n\nHey`);

      assert.dom(".onebox-wrapper").exists("renders the onebox");
      assert.deepEqual(state.changes, [], "doesn't report a value change");
    });
  }
);
