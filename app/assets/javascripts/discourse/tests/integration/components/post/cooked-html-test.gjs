import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostCookedHtml from "discourse/components/post/cooked-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post, { highlightTerm } = {}) {
  return render(
    <template>
      <PostCookedHtml @post={{post}} @highlightTerm={{highlightTerm}} />
    </template>
  );
}

module("Integration | Component | Post | PostCookedHtml", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "enabled";

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    const post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.post = post;
  });

  test("quotes with no username and no valid topic", async function (assert) {
    this.post.cooked = `<aside class=\"quote no-group quote-post-not-found\" data-post=\"1\" data-topic=\"123456\">\n<blockquote>\n<p>abcd</p>\n</blockquote>\n</aside>\n<p>Testing the issue</p>`;

    await renderComponent(this.post);

    assert.dom("blockquote").hasText("abcd");
  });
});
