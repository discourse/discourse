import { getOwner } from "@ember/owner";
import {
  click,
  render,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import NestedActivityLog from "discourse/components/modal/nested-activity-log";
import NestedActivityLogItem from "discourse/components/modal/nested-activity-log/item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | Modal | NestedActivityLogItem",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", { id: 1 });
      this.post = store.createRecord("post", {
        id: 123,
        post_number: 2,
        post_type: 3,
        topic,
        topic_id: topic.id,
        user_id: 42,
        username: "activity-author",
        avatar_template: "/letter_avatar_proxy/v4/letter/a/13edae/{size}.png",
        action_code: "closed.enabled",
        created_at: "2025-09-23T16:10:28.695Z",
        cooked: "<p>Activity details</p>",
        can_edit: true,
        can_delete: true,
        can_recover: false,
      });
      this.currentUser.staff = true;
    });

    test("uses the canonical small-action renderer and forwards controls", async function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer("post-small-action-icon", () => "heart");
        api.registerValueTransformer("post-small-action-class", ({ value }) => [
          ...value,
          "plugin-activity-class",
        ]);
      });

      const editPost = (post) => {
        assert.strictEqual(post, this.post, "forwards the post to edit");
      };
      const deletePost = (post) => {
        assert.strictEqual(post, this.post, "forwards the post to delete");
      };
      const recoverPost = () => {};

      await render(
        <template>
          <ul>
            <NestedActivityLogItem
              @action={{this.post}}
              @topicId={{1}}
              @editPost={{editPost}}
              @deletePost={{deletePost}}
              @recoverPost={{recoverPost}}
            />
          </ul>
        </template>
      );

      assert
        .dom(".nested-activity-log-modal__post .small-action")
        .hasClass("plugin-activity-class");
      assert.dom(".nested-activity-log-modal__post .d-icon-heart").exists();
      assert
        .dom(".nested-activity-log-modal__post .small-action-custom-message")
        .hasText("Activity details");

      await click(".nested-activity-log-modal__post .small-action-edit");
      await click(".nested-activity-log-modal__post .small-action-delete");
    });

    test("keeps the synthetic topic-created row read-only", async function (assert) {
      const syntheticAction = {
        synthetic: true,
        action_code: "topic_created",
        created_at: "2025-09-23T16:10:28.695Z",
        user_id: 42,
        username: "activity-author",
        avatar_template: "/letter_avatar_proxy/v4/letter/a/13edae/{size}.png",
      };

      await render(
        <template>
          <ul>
            <NestedActivityLogItem @action={{syntheticAction}} @topicId={{1}} />
          </ul>
        </template>
      );

      assert.dom(".nested-activity-log-modal__icon .d-icon-plus").exists();
      assert.dom(".nested-activity-log-modal__post").doesNotExist();
      assert.dom(".small-action-buttons").doesNotExist();
    });
  }
);

module("Integration | Component | Modal | NestedActivityLog", function (hooks) {
  setupRenderingTest(hooks);

  const SYNTHETIC_ROW = {
    synthetic: true,
    action_code: "topic_created",
    created_at: "2025-09-23T16:10:28.695Z",
    user_id: 42,
    username: "activity-author",
    avatar_template: "/letter_avatar_proxy/v4/letter/a/13edae/{size}.png",
  };

  function activityPost(id) {
    return {
      id,
      post_number: id,
      post_type: 3,
      topic_id: 1,
      user_id: 42,
      username: "activity-author",
      avatar_template: "/letter_avatar_proxy/v4/letter/a/13edae/{size}.png",
      action_code: "closed.enabled",
      created_at: "2025-09-23T16:10:28.695Z",
    };
  }

  test("keeps existing rows mounted while refreshing", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const appEvents = getOwner(this).lookup("service:app-events");
    const topic = store.createRecord("topic", { id: 1, slug: "topic-1" });
    const model = { topic, editPost() {} };
    const closeModal = () => {};
    let holdRefresh = false;
    let refreshRequested = false;
    let releaseRefresh;

    pretender.get("/n/topic-1/1/activity.json", async () => {
      if (holdRefresh) {
        refreshRequested = true;
        await new Promise((resolve) => (releaseRefresh = resolve));
      }

      return response({ small_actions: [SYNTHETIC_ROW], has_more: false });
    });

    await render(
      <template>
        <NestedActivityLog
          @model={{model}}
          @closeModal={{closeModal}}
          @inline={{true}}
        />
      </template>
    );
    await waitFor(".nested-activity-log-modal__item");

    assert
      .dom(".nested-activity-log-modal__item")
      .exists("renders the initial activity");

    holdRefresh = true;
    appEvents.trigger("nested-replies:activity-changed", { topicId: topic.id });
    await waitUntil(() => refreshRequested);

    assert
      .dom(".nested-activity-log-modal__item")
      .exists("retains the activity while the refresh is in flight");
    assert
      .dom(".nested-activity-log-modal .spinner")
      .doesNotExist("does not replace existing rows with the blocking spinner");

    releaseRefresh();
    await settled();
  });

  test("discards a stale load-more response once a refresh supersedes it", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const appEvents = getOwner(this).lookup("service:app-events");
    const topic = store.createRecord("topic", { id: 1, slug: "topic-1" });
    const model = { topic, editPost() {} };
    const closeModal = () => {};
    let firstPageRequests = 0;
    let holdSecondPage = false;
    let secondPageRequested = false;
    let releaseSecondPage;

    pretender.get("/n/topic-1/1/activity.json", async (request) => {
      if (Number(request.queryParams.page) === 0) {
        firstPageRequests += 1;
        const actions =
          firstPageRequests === 1
            ? [SYNTHETIC_ROW]
            : [SYNTHETIC_ROW, activityPost(600)];
        return response({ small_actions: actions, has_more: true });
      }

      if (holdSecondPage) {
        secondPageRequested = true;
        await new Promise((resolve) => (releaseSecondPage = resolve));
      }

      return response({ small_actions: [activityPost(500)], has_more: false });
    });

    await render(
      <template>
        <NestedActivityLog
          @model={{model}}
          @closeModal={{closeModal}}
          @inline={{true}}
        />
      </template>
    );
    await waitFor(".nested-activity-log-modal__item");

    holdSecondPage = true;
    click(".nested-activity-log-modal__load-more button");
    await waitUntil(() => secondPageRequested);

    appEvents.trigger("nested-replies:activity-changed", { topicId: topic.id });
    await waitFor("[data-post-id='600']");

    releaseSecondPage();
    await settled();

    assert
      .dom("[data-post-id='500']")
      .doesNotExist("does not append the superseded load-more page");
    assert
      .dom(".nested-activity-log-modal__item")
      .exists({ count: 2 }, "shows only the refreshed first page");
    assert
      .dom(".nested-activity-log-modal__load-more button")
      .exists("still offers load more for the refreshed state");
  });
});
