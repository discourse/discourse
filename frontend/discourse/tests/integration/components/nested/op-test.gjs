import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { modifier } from "ember-modifier";
import { module, test } from "qunit";
import NestedOp from "discourse/components/nested/op";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const noop = () => {};
const registerPost = modifier(() => {});

function renderComponent(context) {
  return render(
    <template>
      <NestedOp
        @post={{context.post}}
        @topic={{context.topic}}
        @editPost={{noop}}
        @showHistory={{noop}}
        @replyToPost={{noop}}
        @changeNotice={{noop}}
        @changePostOwner={{noop}}
        @grantBadge={{noop}}
        @lockPost={{noop}}
        @unlockPost={{noop}}
        @permanentlyDeletePost={{noop}}
        @rebakePost={{noop}}
        @showPagePublish={{noop}}
        @togglePostType={{noop}}
        @toggleWiki={{noop}}
        @unhidePost={{noop}}
        @showPostMenu={{context.showPostMenu}}
        @registerPost={{registerPost}}
        @multiSelect={{context.multiSelect}}
        @togglePostSelection={{context.togglePostSelection}}
        @selectReplies={{context.selectReplies}}
        @selectBelow={{context.selectBelow}}
        @postSelected={{context.postSelected}}
      />
    </template>
  );
}

module("Integration | Component | Nested | Op", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
    this.topic = this.store.createRecord("topic", {
      id: 1,
      slug: "nested-topic",
      posts_count: 2,
      views: 1,
      word_count: 1,
      like_count: 0,
      participant_count: 0,
      is_nested_view: true,
    });
    this.multiSelect = false;
    this.showPostMenu = false;
    this.togglePostSelection = noop;
    this.selectReplies = noop;
    this.selectBelow = noop;
    this.postSelected = () => false;
    this.post = this.store.createRecord("post", {
      id: 1,
      post_number: 1,
      topic: this.topic,
      user_id: 1,
      username: "op-user",
      avatar_template: "/letter_avatar_proxy/v4/letter/o/25/48.png",
      cooked: "<p>Original post</p>",
      created_at: "2026-01-01T00:00:00.000Z",
      actions_summary: [],
    });
  });

  test("does not render the flat replies button in the nested OP menu", async function (assert) {
    this.showPostMenu = true;
    this.post.set("reply_count", 3);

    await renderComponent(this);

    assert
      .dom(".nested-view__op-menu .post-action-menu__show-replies")
      .doesNotExist("nested OP menu suppresses the flat replies button");
  });

  test("renders multi-select controls for the OP", async function (assert) {
    let selectedPost;
    this.multiSelect = true;
    this.togglePostSelection = (post) => {
      selectedPost = post;
    };

    await renderComponent(this);

    assert
      .dom(".select-post")
      .hasText(i18n("topic.multi_select.select_post.label"));
    assert
      .dom(".select-below")
      .doesNotExist("does not render select-below for the first post");

    await click(".select-post");

    assert.strictEqual(selectedPost, this.post, "passes the OP to selection");
  });

  test("marks the selected OP", async function (assert) {
    this.multiSelect = true;
    this.postSelected = (post) => post === this.post;

    await renderComponent(this);

    assert
      .dom(".nested-view__op-article")
      .hasClass("selected", "adds the selected state class");
    assert
      .dom(".select-post")
      .hasText(i18n("topic.multi_select.selected_post.label"));
  });
});
