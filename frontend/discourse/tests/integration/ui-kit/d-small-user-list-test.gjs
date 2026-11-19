import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSmallUserList from "discourse/ui-kit/d-small-user-list";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DSmallUserList", function (hooks) {
  setupRenderingTest(hooks);

  test("renders avatars and support for unknown", async function (assert) {
    const users = [
      { id: 456, username: "eviltrout" },
      { id: 457, username: "someone", unknown: true },
    ];

    await render(<template><DSmallUserList @users={{users}} /></template>);

    assert.dom(".small-user-list").exists();
    assert.dom('[data-user-card="eviltrout"]').exists({ count: 1 });
    assert.dom('[data-user-card="someone"]').doesNotExist();
    assert.dom(".unknown").exists("includes unknown user");
  });

  test("links the description to the post of the first user who has one", async function (assert) {
    const users = [
      { username: "eviltrout" },
      { username: "sam", post_url: "/t/a-topic/1/2" },
      { username: "jeff", post_url: "/t/a-topic/1/3" },
    ];

    await render(
      <template>
        <DSmallUserList
          @count={{3}}
          @description="post.actions.people.like"
          @users={{users}}
        />
      </template>
    );

    assert
      .dom(".small-user-list-content > a .list-description")
      .hasText(i18n("post.actions.people.like", { count: 3 }));
    assert
      .dom(".small-user-list-content > a:has(.list-description)")
      .hasAttribute("href", "/t/a-topic/1/2", "the link goes to the post");
  });
});
