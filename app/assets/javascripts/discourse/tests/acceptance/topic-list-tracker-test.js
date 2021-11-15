import {
  nextTopicUrl,
  previousTopicUrl,
  setTopicId,
} from "discourse/lib/topic-list-tracker";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Topic list tracking", function () {
  test("Navigation", async function (assert) {
    await visit("/");
    let url = await nextTopicUrl();
    assert.strictEqual(url, "/t/error-after-upgrade-to-0-9-7-9/11557");

    setTopicId(11557);

    url = await nextTopicUrl();
    assert.strictEqual(url, "/t/welcome-to-meta-discourse-org/1");

    url = await previousTopicUrl();
    assert.strictEqual(url, "/t/error-after-upgrade-to-0-9-7-9/11557");
  });
});
