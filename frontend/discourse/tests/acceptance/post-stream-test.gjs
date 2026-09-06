import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Post-Stream | @topicPageQueryParams reactivity", function (needs) {
  needs.user();
  needs.settings({
    enable_filtered_replies_view: true,
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

acceptance("Post-Stream | cooked HTML stability", function (needs) {
  needs.user();

  let decorateCounts;

  needs.hooks.beforeEach(function () {
    decorateCounts = {};

    withPluginApi((api) => {
      api.decorateCookedElement(
        (cooked, helper) => {
          const id = helper?.getModel?.()?.id;
          if (!id) {
            return;
          }

          decorateCounts[id] = (decorateCounts[id] || 0) + 1;

          const injected = document.createElement("span");
          injected.className = "injected-by-decorator";
          cooked.appendChild(injected);
        },
        { onlyStream: true }
      );
    });
  });

  test("appending posts does not rebuild the cooked HTML of existing posts", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const postStream = this.owner.lookup("controller:topic").model.postStream;
    const firstPost = postStream.posts[0];

    const cookedBefore = document.querySelector("#post_1 .cooked");
    const injectedBefore = document.querySelector(
      "#post_1 .injected-by-decorator"
    );

    assert.dom("#post_1 .cooked").exists("the first post is rendered");
    assert
      .dom("#post_1 .injected-by-decorator")
      .exists("the decorator injected into the first post");
    assert.strictEqual(
      decorateCounts[firstPost.id],
      1,
      "the first post is decorated once on initial render"
    );

    const before = postStream.posts.length;
    postStream.appendPost(
      postStream.store.createRecord("post", {
        id: 9001,
        post_number: 9001,
        topic_id: postStream.topic.id,
        cooked: "<p>appended</p>",
        username: "eviltrout",
        created_at: "2013-02-05T21:29:00.280Z",
      })
    );
    await settled();

    assert.strictEqual(
      postStream.posts.length,
      before + 1,
      "a post was appended"
    );
    assert.dom("#post_9001").exists("the appended post was rendered");
    assert.strictEqual(
      document.querySelector("#post_1 .cooked"),
      cookedBefore,
      "the first post keeps the same cooked element"
    );
    assert.strictEqual(
      document.querySelector("#post_1 .injected-by-decorator"),
      injectedBefore,
      "DOM injected by a decorator survives the append"
    );
    assert.strictEqual(
      decorateCounts[firstPost.id],
      1,
      "the first post is not decorated again"
    );
  });

  test("prepending posts does not rebuild the cooked HTML of existing posts", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const postStream = this.owner.lookup("controller:topic").model.postStream;
    // the post kept in view while earlier posts are loaded above it
    const anchorPost = postStream.posts.at(-1);
    const anchorSelector = `#post_${anchorPost.post_number}`;

    const cookedBefore = document.querySelector(`${anchorSelector} .cooked`);
    const injectedBefore = document.querySelector(
      `${anchorSelector} .injected-by-decorator`
    );

    // guards the identity assertions below against passing on null === null
    assert
      .dom(`${anchorSelector} .cooked`)
      .exists("the anchor post is rendered");
    assert
      .dom(`${anchorSelector} .injected-by-decorator`)
      .exists("the decorator injected into the anchor post");
    assert.strictEqual(
      decorateCounts[anchorPost.id],
      1,
      "the anchor post is decorated once on initial render"
    );

    const before = postStream.posts.length;
    postStream.prependPost(
      postStream.store.createRecord("post", {
        id: 9002,
        post_number: 0,
        topic_id: postStream.topic.id,
        cooked: "<p>prepended</p>",
        username: "eviltrout",
        created_at: "2013-02-05T21:29:00.280Z",
      })
    );
    await settled();

    assert.strictEqual(
      postStream.posts.length,
      before + 1,
      "a post was prepended"
    );
    assert.dom("#post_0").exists("the prepended post was rendered");
    assert.strictEqual(
      document.querySelector(`${anchorSelector} .cooked`),
      cookedBefore,
      "the anchor post keeps the same cooked element"
    );
    assert.strictEqual(
      document.querySelector(`${anchorSelector} .injected-by-decorator`),
      injectedBefore,
      "DOM injected by a decorator survives the prepend"
    );
    assert.strictEqual(
      decorateCounts[anchorPost.id],
      1,
      "the anchor post is not decorated again"
    );
  });
});

acceptance("Post-Stream | neighbor reactivity", function (needs) {
  needs.user();

  test("a mid-stream insert refreshes the neighbor-derived output of the post below it", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const postStream = this.owner.lookup("controller:topic").model.postStream;
    // retains both its key and its index across the insert; only its
    // `previousPost` changes, so it is only re-rendered if that stays live
    const shiftedPost = postStream.posts[1];

    assert
      .dom(".time-gap")
      .doesNotExist("the fixture posts are too close together to show a gap");

    // far enough back that `shiftedPost` clears show_time_gap_days (7) once
    // this post becomes the one above it
    const inserted = postStream.storePost(
      postStream.store.createRecord("post", {
        id: 9003,
        post_number: 9003,
        topic_id: postStream.topic.id,
        cooked: "<p>inserted</p>",
        username: "eviltrout",
        created_at: "2010-01-01T00:00:00.000Z",
      })
    );
    postStream.posts.splice(1, 0, inserted);
    await settled();

    assert.dom("#post_9003").exists("the inserted post was rendered");

    const shiftedElement = document.querySelector(
      `#post_${shiftedPost.post_number}`
    );
    assert.dom(shiftedElement).exists("the shifted post is still rendered");
    assert
      .dom(".time-gap")
      .exists(
        { count: 1 },
        "a time gap derived from the new previous post renders"
      );

    // the id is on the inner <article>, so step out to the post wrapper the
    // gap is actually a sibling of
    assert
      .dom(shiftedElement.parentElement.previousElementSibling)
      .hasClass(
        "time-gap",
        "the time gap renders directly above the shifted post"
      );
  });
});
