import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMetaData from "discourse/components/post/meta-data";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostMetaData @post={{post}} /></template>);
}

module("Integration | Component | Post | PostMetaData", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "enabled";

    this.store = getOwner(this).lookup("service:store");
    const topic = this.store.createRecord("topic", { id: 1 });
    const post = this.store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      created_at: "2025-06-01T00:31:24.008Z",
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.post = post;
  });

  test("post-meta-data-infos value transformer (DAG API)", async function (assert) {
    this.post.username = "eviltrout";
    this.post.user = this.store.createRecord("user", {
      username: "eviltrout",
    });
    withPluginApi((api) => {
      const TestComponent = <template>
        <div class="post-info post-metadata-test"></div>
      </template>;

      api.registerValueTransformer(
        "post-meta-data-infos",
        ({ value: metadata, context: { metaDataInfoKeys } }) => {
          metadata.add("activity-pub-indicator", TestComponent, {
            before: metaDataInfoKeys.DATE,
            after: metaDataInfoKeys.REPLY_TO_TAB,
          });
        }
      );
    });

    await renderComponent(this.post);

    assert
      .dom("div.post-info.post-date")
      .exists("the date metadata is present");
    assert
      .dom("div.post-info.post-metadata-test")
      .exists("the test component is present");
    assert
      .dom(
        "div.post-info.post-metadata-test:nth-child(1) + div.post-info.post-date:nth-child(2)"
      )
      .exists("the expected order is correct");
  });
});
