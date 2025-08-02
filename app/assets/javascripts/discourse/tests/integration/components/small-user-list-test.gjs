import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SmallUserList from "discourse/components/small-user-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | SmallUserList", function (hooks) {
  setupRenderingTest(hooks);

  test("renders avatars and support for unknown", async function (assert) {
    const users = [
      { id: 456, username: "eviltrout" },
      { id: 457, username: "someone", unknown: true },
    ];

    await render(<template><SmallUserList @users={{users}} /></template>);

    assert.dom(".small-user-list").exists();
    assert.dom('[data-user-card="eviltrout"]').exists({ count: 1 });
    assert.dom('[data-user-card="someone"]').doesNotExist();
    assert.dom(".unknown").exists("includes unknown user");
  });
});
