import { tracked } from "@glimmer/tracking";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminPenaltyPostAction from "discourse/admin/components/admin-penalty-post-action";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | AdminPenaltyPostAction", function (hooks) {
  setupRenderingTest(hooks);

  test("reports the action and the edited post", async function (assert) {
    const postAction = tracked("delete");
    const edits = [];
    const readiness = [];
    const changePostAction = (value) => (postAction.value = value);
    const changePostEdit = (value) => edits.push(value);
    const deleteAllPostsReady = (ready) => readiness.push(ready);
    const user = { trust_level: 1, topic_count: 2, post_count: 5 };

    await render(
      <template>
        <div class="d-modal__body">
          <AdminPenaltyPostAction
            @onChangePostAction={{changePostAction}}
            @onChangePostEdit={{changePostEdit}}
            @onDeleteAllPostsReady={{deleteAllPostsReady}}
            @postAction={{postAction.value}}
            @postEdit="original post"
            @user={{user}}
          />
        </div>
      </template>
    );

    assert.dom(".post-editor").doesNotExist();

    await selectKit(".penalty-post-controls .combo-box").expand();
    await selectKit(".penalty-post-controls .combo-box").selectRowByValue(
      "edit"
    );

    assert.strictEqual(postAction.value, "edit", "reports the picked action");
    assert.dom(".post-editor").hasValue("original post");

    await fillIn(".post-editor", "edited post");
    assert.deepEqual(edits, ["edited post"], "reports the edited post");

    await selectKit(".penalty-post-controls .combo-box").expand();
    await selectKit(".penalty-post-controls .combo-box").selectRowByValue(
      "delete_all"
    );
    assert
      .dom(".penalty-post-controls .select-kit-header")
      .isFocused("returns focus to the dropdown for other actions");

    await click(".penalty-post-controls ~ label input[type='checkbox']");

    assert.deepEqual(readiness, [true], "reports the confirmed delete");
  });
});
