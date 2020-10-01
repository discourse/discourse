import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  nextTopicUrl,
  previousTopicUrl,
  setTopicId,
} from "discourse/lib/topic-list-tracker";
acceptance("Topic list tracking");

QUnit.test("Navigation", async (assert) => {
  await visit("/");
  let url = await nextTopicUrl();
  assert.equal(url, "/t/error-after-upgrade-to-0-9-7-9/11557");

  setTopicId(11557);

  url = await nextTopicUrl();
  assert.equal(url, "/t/welcome-to-meta-discourse-org/1");

  url = await previousTopicUrl();
  assert.equal(url, "/t/error-after-upgrade-to-0-9-7-9/11557");
});
