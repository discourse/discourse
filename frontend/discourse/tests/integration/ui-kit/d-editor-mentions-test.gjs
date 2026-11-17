import { render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DEditor from "discourse/ui-kit/d-editor";

module("Integration | Component | DEditor", function (hooks) {
  setupRenderingTest(hooks);

  for (const [modeName, mode] of Object.entries(
    USER_OPTION_COMPOSITION_MODES
  )) {
    for (const topicId of [undefined, 42]) {
      test(`${modeName} mention requests include their context ${topicId ? "in existing topics" : "before a topic is saved"}`, async function (assert) {
        this.siteSettings.enable_mentions = true;

        const requests = [];
        let textManipulation;
        const onSetup = (instance) => {
          textManipulation = instance;
        };

        pretender.get("/u/search/users", (request) => {
          requests.push(request.queryParams);
          return response({
            users: [
              { username: `user_category_${request.queryParams.category_id}` },
            ],
          });
        });

        await render(
          <template>
            <DEditor
              @categoryId={{1}}
              @forceEditorMode={{mode}}
              @onSetup={{onSetup}}
              @processPreview={{false}}
              @topicId={{topicId}}
            />
            <DMenus />
          </template>
        );

        if (mode === USER_OPTION_COMPOSITION_MODES.rich) {
          const { view } = textManipulation;
          view.dispatch(view.state.tr.insertText("@u"));
          view.focus();
        } else {
          textManipulation.insertText("@u");
        }
        await triggerKeyEvent(".d-editor-input", "keyup", "U");

        assert.strictEqual(
          requests.length,
          1,
          "typing a mention searches users"
        );
        assert.strictEqual(
          requests[0].category_id,
          "1",
          "the request uses the selected category"
        );
        assert.strictEqual(
          requests[0].search_context,
          "mention",
          "the request identifies a mention search"
        );
        assert.strictEqual(
          requests[0].topic_id,
          topicId?.toString(),
          "the request preserves the existing topic context"
        );
      });
    }
  }
});
