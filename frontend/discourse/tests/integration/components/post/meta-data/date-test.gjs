import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMetaDataDate from "discourse/components/post/meta-data/date";
import { relativeAge } from "discourse/lib/formatter";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostMetaDataDate @post={{post}} /></template>);
}

module("Integration | Component | Post | PostMetaDataDate", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
    const topic = this.store.createRecord("topic", { id: 1 });
    const post = this.store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      created_at: "2025-06-01T00:31:24.008Z",
    });

    this.post = post;
  });

  test("uses an abbreviated date for the accessible label", async function (assert) {
    await renderComponent(this.post);

    assert.dom("a.post-date").hasAria(
      "label",
      relativeAge(new Date(this.post.created_at), {
        format: "medium-with-ago",
        wrapInSpan: false,
      }),
      "the link is announced with an abbreviated date instead of the full date and time"
    );

    assert
      .dom("a.post-date > span[aria-hidden=true] .relative-date")
      .exists("the relative date and its tooltip are accessibility-hidden");
  });
});
