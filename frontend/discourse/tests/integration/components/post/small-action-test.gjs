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
import PostSmallAction from "discourse/components/post/small-action";
import { shortDate } from "discourse/lib/formatter";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import I18n from "discourse-i18n";

function renderComponent(post) {
  return render(<template><PostSmallAction @post={{post}} /></template>);
}

module("Integration | Component | Post | PostSmallAction", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    const post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      action_code: "open_topic",
      action_code_who: "tester",
      action_code_path: "/p/123",
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
      created_at: "2025-09-23T16:10:28.695Z",
    });

    this.post = post;
  });

  test("does not have delete/edit/recover buttons by default", async function (assert) {
    await renderComponent(this.post);

    assert.dom(".small-action-desc .small-action-delete").doesNotExist();
    assert.dom(".small-action-desc .small-action-recover").doesNotExist();
    assert.dom(".small-action-desc .small-action-edit").doesNotExist();
  });

  test("shows edit button if canEdit", async function (assert) {
    this.post.can_edit = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-edit")
      .exists("adds the edit small action button");
  });

  test("can add classes to the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-small-action-class", ({ value }) => {
        value.push("custom-class");
        return value;
      });

      api.addPostSmallActionClassesCallback(
        (post) => `api-custom-class-${post.id}`
      );
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action.custom-class.api-custom-class-123")
      .exists("applies the custom classes to the component");
  });

  test("can use a custom component", async function (assert) {
    let contextCode, contextPost;

    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-small-action-custom-component",
        ({ context: { code, post } }) => {
          contextCode = code;
          contextPost = post;

          return <template>
            <div class="custom-component">
              CUSTOM COMPONENT for
              <span class="test-code">{{@code}}</span>
              <span class="test-post">{{@post.post_number}}</span>
              <span class="test-who">{{@who}}</span>
              <span class="test-created-at">{{shortDate @createdAt}}</span>
              <span class="test-path">{{@path}}</span>
            </div>
          </template>;
        }
      );
    });

    await renderComponent(this.post);

    assert.strictEqual(
      contextCode,
      "open_topic",
      "the action code was passed as parameter to the transformer"
    );
    assert.strictEqual(
      contextPost.id,
      this.post.id,
      "the post was passed as parameter to the transformer"
    );

    assert
      .dom(".small-action .custom-component")
      .exists("uses the custom component");
    assert
      .dom(".small-action .small-action-custom-message")
      .doesNotExist("won't render the cooked test");

    assert
      .dom(".small-action .custom-component .test-code")
      .hasText("open_topic", "the custom component received the correct code");
    assert
      .dom(".small-action .custom-component .test-post")
      .hasText("1", "the custom component received the correct post number");
    assert
      .dom(".small-action .custom-component .test-who")
      .hasText("tester", "the custom component received the correct who");
    assert
      .dom(".small-action .custom-component .test-created-at")
      .hasText(
        "Sep 23, 2025",
        "the custom component received the correct created_at"
      );
    assert
      .dom(".small-action .custom-component .test-path")
      .hasText("/p/123", "the custom component received the correct path");
  });

  test("can customize the icon of the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-small-action-icon",
        () => "far-circle-check"
      );
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action .d-icon-far-circle-check")
      .exists("the custom icon was rendered");
  });

  test("api.addGroupPostSmallActionCode", async function (assert) {
    withPluginApi((api) => {
      api.addGroupPostSmallActionCode("some_code");
    });

    this.post.action_code = "some_code";
    this.post.action_code_who = "somegroup";

    I18n.translations[I18n.locale].js.action_codes = {
      some_code: "Some %{who} Code Action",
    };

    await renderComponent(this.post);

    assert
      .dom(".small-action")
      .hasText(
        "Some @somegroup Code Action",
        "the action code text was rendered correctly"
      );

    assert
      .dom("a.mention-group")
      .hasAttribute(
        "href",
        "/g/somegroup",
        "the group mention link has the correct href"
      );
  });

  test("api.addPostSmallActionIcon", async function (assert) {
    withPluginApi((api) => {
      api.addPostSmallActionIcon("open_topic", "far-circle-check");
      api.addPostSmallActionIcon("private_topic", "heart");
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action .d-icon-far-circle-check")
      .exists("the correct custom icon was rendered");
  });

  test("does not show edit button if canRecover even if canEdit", async function (assert) {
    this.post.can_edit = true;
    this.post.deleted_at = new Date().toISOString();
    this.post.can_recover = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-edit")
      .doesNotExist("does not add the edit small action button");
    assert
      .dom(".small-action-desc .small-action-recover")
      .exists("adds the recover small action button");
  });

  test("shows delete button if canDelete", async function (assert) {
    this.post.can_delete = true;
    this.currentUser.staff = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-delete")
      .exists("adds the delete small action button");
  });

  test("shows undo button if canRecover", async function (assert) {
    this.post.deleted_at = new Date().toISOString();
    this.post.can_recover = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-recover")
      .exists("adds the recover small action button");
  });

  test("a11y heading is rendered even when small action is cloaked", async function (assert) {
    await render(
      <template>
        <PostSmallAction @post={{this.post}} @cloaked={{true}} />
      </template>
    );

    assert
      .dom("h2.sr-only")
      .exists("accessibility heading exists even when cloaked");
    assert
      .dom("h2.sr-only")
      .hasAttribute(
        "id",
        `post-heading-${this.post.post_number}`,
        "heading has correct id when cloaked"
      );

    // The main content should not be rendered when cloaked
    assert
      .dom("article .small-action-desc")
      .doesNotExist("main content is not rendered when cloaked");
    assert
      .dom("article .topic-avatar")
      .doesNotExist("avatar icon is not rendered when cloaked");
  });

  test("article is properly labeled by a11y heading", async function (assert) {
    await renderComponent(this.post);

    const expectedAriaLabelledBy = `post-heading-${this.post.post_number}`;

    assert
      .dom("article.small-action")
      .hasAttribute(
        "aria-labelledby",
        expectedAriaLabelledBy,
        "article is labeled by the accessibility heading"
      );
  });

  test("a11y heading id is unique for different post numbers", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });

    const post1 = store.createRecord("post", {
      id: 100,
      post_number: 1,
      topic,
      action_code: "open_topic",
      created_at: "2025-09-23T16:10:28.695Z",
    });

    const post2 = store.createRecord("post", {
      id: 200,
      post_number: 2,
      topic,
      action_code: "closed.enabled",
      created_at: "2025-09-23T16:10:28.695Z",
    });

    // Render both posts
    await render(
      <template>
        <PostSmallAction @post={{post1}} />
        <PostSmallAction @post={{post2}} />
      </template>
    );

    assert.dom("#post-heading-1").exists("first post heading has correct id");
    assert.dom("#post-heading-2").exists("second post heading has correct id");
  });
});

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

  test("keeps existing rows mounted while refreshing", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const appEvents = getOwner(this).lookup("service:app-events");
    const topic = store.createRecord("topic", { id: 1, slug: "topic-1" });
    const model = { topic, editPost() {} };
    const closeModal = () => {};
    const activity = {
      synthetic: true,
      action_code: "topic_created",
      created_at: "2025-09-23T16:10:28.695Z",
      user_id: 42,
      username: "activity-author",
      avatar_template: "/letter_avatar_proxy/v4/letter/a/13edae/{size}.png",
    };
    let holdRefresh = false;
    let refreshRequested = false;
    let releaseRefresh;

    pretender.get("/n/topic-1/1/activity.json", async () => {
      if (holdRefresh) {
        refreshRequested = true;
        await new Promise((resolve) => (releaseRefresh = resolve));
      }

      return response({ small_actions: [activity], has_more: false });
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
});
