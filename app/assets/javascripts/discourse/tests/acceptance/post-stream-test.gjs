import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Post-Stream | @topicPageQueryParams reactivity", function (needs) {
  needs.user();
  needs.settings({
    enable_filtered_replies_view: true,
    glimmer_post_stream_mode: "enabled",
  });

  needs.hooks.beforeEach(function () {
    withPluginApi((api) => {
      api.renderBeforeWrapperOutlet(
        "post-article",
        <template>
          <div class="topic-page-query-params-test">
            <span class="topic-page-query-params-value">
              {{@topicPageQueryParams.replies_to_post_number}}
            </span>
          </div>
        </template>
      );
    });
  });

  test("topicPageQueryParams is reactive", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom(".topic-page-query-params-test")
      .exists("The test component is rendered");

    // get the initial value of replies_to_post_number
    const initialValue = document.querySelector(
      ".topic-page-query-params-value"
    ).textContent;

    // click on a post to filter replies
    await click("#post_1 .show-replies");

    // get the updated value of replies_to_post_number
    let updatedValue = document
      .querySelector(".topic-page-query-params-value")
      .textContent.trim();

    // verify that the value has changed
    assert.notStrictEqual(
      initialValue,
      updatedValue,
      "topicPageQueryParams value changes when filtering replies"
    );

    assert.strictEqual(
      updatedValue,
      "1",
      "replies_to_post_number parameter is updated to 1"
    );

    // click on another post to filter replies
    await click("#post_3 .show-replies");

    updatedValue = document
      .querySelector(".topic-page-query-params-value")
      .textContent.trim();

    // verify that the value has changed again
    assert.strictEqual(
      updatedValue,
      "3",
      "replies_to_post_number parameter is updated to 3"
    );
  });
});
