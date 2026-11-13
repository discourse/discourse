import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
import RssPollingFeedForm from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-form";

module("Integration | Component | RssPollingFeedForm", function (hooks) {
  setupRenderingTest(hooks);

  test("with the new select controls, the picked author is saved as a username", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    pretender.get("/u/search/users", () =>
      response({
        users: [{ username: "bob", name: "Bob", avatar_template: "/a/{size}" }],
      })
    );
    let body;
    pretender.put("/admin/plugins/rss_polling/feed_settings", (request) => {
      body = JSON.parse(request.requestBody);
      return response({ id: 3 });
    });
    const feed = { id: 3, feed_url: "https://example.com/feed", author: null };

    await render(<template><RssPollingFeedForm @feed={{feed}} /></template>);
    const author = dSelect(".rss-polling-feed-form__author");
    await author.search("bo");
    await author.selectByName("bob");
    await formKit().submit();

    assert.strictEqual(body.feed_setting.author_username, "bob");
  });
});
