import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { modifier } from "ember-modifier";
import { module, test } from "qunit";
import sinon from "sinon";
import NestedPost from "discourse/components/nested/post";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
        @depth={{context.depth}}
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
        @focusPost={{context.focusPost}}
        @registerPost={{registerPost}}
        @collapseFromDepth={{context.collapseFromDepth}}
        @multiSelect={{context.multiSelect}}
        @togglePostSelection={{context.togglePostSelection}}
        @selectReplies={{context.selectReplies}}
        @selectBelow={{context.selectBelow}}
        @postSelected={{context.postSelected}}
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
    this.depth = 0;
    this.collapseFromDepth = null;
    this.expansionState = new Map();
    this.fetchedChildrenCache = new Map();
    this.multiSelect = false;
    this.togglePostSelection = noop;
    this.selectReplies = noop;
    this.selectBelow = noop;
    this.postSelected = () => false;
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

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("uses nested replies affordance instead of flat post-menu replies button", async function (assert) {
    this.post.setProperties({
      reply_count: 2,
      direct_reply_count: 2,
      total_descendant_count: 2,
    });

    await renderComponent(this);

    assert
      .dom(".nested-post__menu .post-action-menu__show-replies")
      .doesNotExist(
        "does not render the flat replies button in nested post menus"
      );
    assert
      .dom(".nested-post__expand-replies")
      .exists("keeps the nested replies expansion button");
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

  test("mobile collapsed posts keep an avatar in the gutter", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    sinon.stub(site, "mobileView").value(true);

    await renderComponent(this);
    await click(".nested-post__depth-line");

    assert.dom(".nested-post__article").doesNotExist("collapses the post body");
    assert
      .dom(".nested-post__gutter .topic-avatar")
      .exists("renders the post avatar area in the mobile gutter");
    assert
      .dom(".nested-post__collapsed-avatar")
      .doesNotExist("does not duplicate the avatar in the collapsed bar");
  });

  test("post registration can update post topic", async function (assert) {
    const appEvents = getOwner(this).lookup("service:app-events");
    const updatedTopic = this.store.createRecord("topic", {
      id: 99,
      slug: "updated-topic",
      user_id: 1,
    });
    let registered = false;
    const register = (post) => {
      post.topic;
      post.topic = updatedTopic;
      registered = true;
    };

    appEvents.on("nested-replies:post-registered", this, register);

    try {
      await renderComponent(this);

      assert.true(registered, "registers the post");
      assert.strictEqual(this.post.topic, updatedTopic, "updates the topic");
    } finally {
      appEvents.off("nested-replies:post-registered", this, register);
    }
  });

  test("mobile focus waits for unloaded children before focusing", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    sinon.stub(site, "mobileView").value(true);

    this.post.set("direct_reply_count", 1);
    this.post.set("total_descendant_count", 1);

    let focusedPath;
    let requestedChildren = false;
    this.focusPost = (path) => {
      focusedPath = path;
    };

    pretender.get("/n/nested-topic/1/children/2.json", (request) => {
      requestedChildren = true;
      assert.strictEqual(
        focusedPath,
        undefined,
        "does not enter focused mode before children are fetched"
      );
      assert.strictEqual(request.queryParams.sort, "top");
      assert.strictEqual(request.queryParams.depth, "1");

      return response({
        children: [
          {
            id: 3,
            post_number: 3,
            topic_id: 1,
            user_id: 3,
            username: "child-user",
            avatar_template: "/letter_avatar_proxy/v4/letter/c/25/48.png",
            cooked: "<p>Child post</p>",
            created_at: "2026-01-01T00:00:00.000Z",
            actions_summary: [],
            direct_reply_count: 0,
            total_descendant_count: 0,
            children: [],
          },
        ],
        has_more: false,
        page: 0,
      });
    });

    await renderComponent(this);
    await click(".nested-post__expand-replies");

    assert.true(requestedChildren, "fetches the missing children first");
    assert.strictEqual(focusedPath.length, 1, "focuses after the request");
    assert.strictEqual(
      focusedPath[0].children[0].post.post_number,
      3,
      "hydrates the focused path with the fetched child"
    );
    assert.strictEqual(
      this.fetchedChildrenCache.get(2).childNodes,
      focusedPath[0].children,
      "stores the fetched children in the shared cache"
    );
  });

  test("reply counts below the mobile depth cap do not preload missing children", async function (assert) {
    this.depth = 3;
    this.collapseFromDepth = 4;
    this.post.set("direct_reply_count", 1);
    this.post.set("total_descendant_count", 1);

    pretender.get("/n/nested-topic/1/children/2.json", () => {
      assert.step("requested children");

      return response({
        children: [],
        has_more: false,
        page: 0,
      });
    });

    await renderComponent(this);

    assert
      .dom(".nested-post__expand-replies")
      .exists("shows the explicit expansion affordance");
    assert
      .dom(".nested-post-children")
      .doesNotExist("does not mount the child loader");
    assert.verifySteps([], "does not request children while rendering");
  });

  test("renders multi-select controls", async function (assert) {
    let selectedPost;
    this.multiSelect = true;
    this.postSelected = () => false;
    this.togglePostSelection = (post) => {
      selectedPost = post;
    };

    await renderComponent(this);

    assert
      .dom(".select-post")
      .hasText(i18n("topic.multi_select.select_post.label"));
    assert
      .dom(".select-below")
      .hasText(i18n("topic.multi_select.select_below.label"));

    await click(".select-post");

    assert.strictEqual(selectedPost, this.post, "passes the post to selection");
  });

  test("marks selected posts", async function (assert) {
    this.multiSelect = true;
    this.postSelected = (post) => post === this.post;

    await renderComponent(this);

    assert
      .dom(".nested-post")
      .hasClass("selected", "adds the selected state class");
    assert
      .dom(".select-post")
      .hasText(i18n("topic.multi_select.selected_post.label"));
  });
});
