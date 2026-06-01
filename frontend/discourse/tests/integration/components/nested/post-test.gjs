import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { modifier } from "ember-modifier";
import { module, test } from "qunit";
import NestedPost from "discourse/components/nested/post";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const noop = () => {};
const registerPost = modifier(() => {});

function renderComponent(context) {
  return render(
    <template>
      <NestedPost
        @post={{context.post}}
        @children={{context.children}}
        @topic={{context.topic}}
        @depth={{0}}
        @path={{context.path}}
        @sort="top"
        @replyToPost={{noop}}
        @editPost={{noop}}
        @deletePost={{noop}}
        @recoverPost={{noop}}
        @showFlags={{noop}}
        @showHistory={{noop}}
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
        @expansionState={{context.expansionState}}
        @fetchedChildrenCache={{context.fetchedChildrenCache}}
        @registerPost={{registerPost}}
      />
    </template>
  );
}

module("Integration | Component | Nested | Post", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.nested_replies_max_depth = 6;
    this.store = getOwner(this).lookup("service:store");
    this.topic = this.store.createRecord("topic", {
      id: 1,
      slug: "nested-topic",
      user_id: 1,
    });
    this.path = [];
    this.children = [];
    this.expansionState = new Map();
    this.fetchedChildrenCache = new Map();
    this.post = this.store.createRecord("post", {
      id: 2,
      post_number: 2,
      topic: this.topic,
      user_id: 2,
      username: "leaf-user",
      avatar_template: "/letter_avatar_proxy/v4/letter/l/25/48.png",
      cooked: "<p>Leaf post</p>",
      created_at: "2026-01-01T00:00:00.000Z",
      actions_summary: [],
      direct_reply_count: 0,
      total_descendant_count: 0,
    });
  });

  test("leaf posts can be collapsed from the depth line", async function (assert) {
    await renderComponent(this);

    assert
      .dom(".nested-post__depth-line")
      .exists("renders a depth-line for a post without replies");
    assert
      .dom(".nested-post__depth-line-icon")
      .exists("renders the collapse affordance");
    assert
      .dom(".nested-post__depth-line")
      .hasClass(
        "nested-post__depth-line--leaf",
        "uses the low-emphasis leaf depth-line"
      );
    assert
      .dom(".nested-post__depth-line")
      .doesNotHaveClass(
        "nested-post__depth-line--collapsed",
        "does not use the replies-hidden line state"
      );

    await click(".nested-post__depth-line");

    assert.dom(".nested-post__article").doesNotExist("collapses the post body");
    assert.dom(".nested-post__collapsed-bar").exists("shows the collapsed bar");
    assert
      .dom(".nested-post__collapsed-reply-count")
      .hasText(i18n("nested_replies.collapsed_post"));
    assert.deepEqual(
      this.expansionState.get(2),
      { expanded: false, collapsed: true },
      "stores the collapsed leaf state"
    );

    await click(".nested-post__collapsed-bar");

    assert.dom(".nested-post__article").exists("expands the post body again");
    assert
      .dom(".nested-post__depth-line")
      .exists("restores the depth-line affordance");
    assert.deepEqual(
      this.expansionState.get(2),
      { expanded: false, collapsed: false },
      "stores the expanded leaf state"
    );
  });
});
