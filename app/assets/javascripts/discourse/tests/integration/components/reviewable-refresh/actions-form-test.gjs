import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableActionsForm from "discourse/components/reviewable-refresh/actions-form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | reviewable-refresh | actions-form",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders dropdowns for each action bundle", async function (assert) {
      const reviewable = {
        id: 123,
        version: 1,
        bundled_actions: [
          {
            id: "123-post-actions",
            label: "Post Actions",
            actions: [
              { id: "keep_post", label: "Keep Post" },
              { id: "hide_post", label: "Hide Post" },
              { id: "delete_post", label: "Delete Post" },
            ],
          },
          {
            id: "123-user-actions",
            label: "User Actions",
            actions: [
              { id: "no_action_user", label: "No Action" },
              { id: "silence_user", label: "Silence User" },
              { id: "suspend_user", label: "Suspend User" },
            ],
          },
        ],
      };

      await render(
        <template>
          <ReviewableActionsForm @reviewable={{reviewable}} />
        </template>
      );

      assert
        .dom(".form-kit__control-select")
        .exists({ count: 2 }, "renders two select dropdowns");

      assert
        .dom(".form-kit__field-select:first-of-type .form-kit__container-title")
        .hasText("Post Actions", "first field has correct label");

      assert
        .dom(".form-kit__field-select:last-of-type .form-kit__container-title")
        .hasText("User Actions", "second field has correct label");
    });

    test("submits selected actions", async function (assert) {
      let capturedData;

      pretender.put("/review/123/perform", (request) => {
        capturedData = request.requestBody;
        return [
          200,
          { "Content-Type": "application/json" },
          JSON.stringify({
            reviewable_perform_result: {
              success: true,
              performed_actions: [
                { action_id: "hide_post", success: true },
                { action_id: "silence_user", success: true },
              ],
            },
          }),
        ];
      });

      const reviewable = {
        id: 123,
        version: 2,
        bundled_actions: [
          {
            id: "post-bundle",
            label: "Post Actions",
            actions: [
              { id: "keep_post", label: "Keep Post" },
              { id: "hide_post", label: "Hide Post" },
            ],
          },
          {
            id: "user-bundle",
            label: "User Actions",
            actions: [
              { id: "no_action", label: "No Action" },
              { id: "silence_user", label: "Silence User" },
            ],
          },
        ],
      };

      let performedResult;
      const onPerformed = (result) => {
        performedResult = result;
      };

      await render(
        <template>
          <ReviewableActionsForm
            @reviewable={{reviewable}}
            @onPerformed={{onPerformed}}
          />
        </template>
      );

      // Change selections
      await formKit().field("post_bundle").select("hide_post");
      await formKit().field("user_bundle").select("silence_user");

      // Submit form
      await formKit().submit();
      await settled();

      assert.notStrictEqual(capturedData, undefined, "API call was made");

      const params = new URLSearchParams(capturedData);
      assert.deepEqual(
        params.getAll("action_ids[]"),
        ["hide_post", "silence_user"],
        "sends correct action_ids"
      );
      assert.strictEqual(params.get("version"), "2", "sends correct version");

      assert.notStrictEqual(
        performedResult,
        undefined,
        "onPerformed callback was called"
      );
      assert.strictEqual(
        performedResult.performed_actions.length,
        2,
        "result contains performed actions"
      );
    });

    test("handles single bundle", async function (assert) {
      const reviewable = {
        id: 123,
        version: 1,
        bundled_actions: [
          {
            id: "single-bundle",
            label: "Actions",
            actions: [
              { id: "action1", label: "Action 1" },
              { id: "action2", label: "Action 2" },
            ],
          },
        ],
      };

      await render(
        <template>
          <ReviewableActionsForm @reviewable={{reviewable}} />
        </template>
      );

      assert
        .dom(".form-kit__field")
        .exists({ count: 1 }, "renders single field group");

      assert
        .dom(".form-kit__control-select")
        .exists({ count: 1 }, "renders single dropdown");

      assert
        .dom(".form-kit__button.btn-primary")
        .exists("still renders submit button for single bundle");
    });

    test("handles empty bundles gracefully", async function (assert) {
      const reviewable = {
        id: 123,
        version: 1,
        bundled_actions: [],
      };

      await render(
        <template>
          <ReviewableActionsForm @reviewable={{reviewable}} />
        </template>
      );

      assert
        .dom(".reviewable-actions-form")
        .exists("renders the form container");

      assert
        .dom(".form-kit__field")
        .doesNotExist("no fields rendered for empty bundles");

      assert
        .dom(".form-kit__button.btn-primary")
        .exists("submit button still rendered");
    });
  }
);
