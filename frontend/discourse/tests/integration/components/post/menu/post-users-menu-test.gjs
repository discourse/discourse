import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostUsersMenu from "discourse/components/post/menu/post-users-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function makeUsers(count) {
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    username: `u${i + 1}`,
    name: `User ${i + 1}`,
    avatar_template: "/user_avatar/avatar/{size}/1_1.png",
  }));
}

function deferredFetch(response) {
  let resolve;
  const promise = new Promise((r) => (resolve = r));
  const fetchUsers = () => promise;
  return {
    fetchUsers,
    resolve: () => resolve(response),
  };
}

module("Integration | Component | post/menu/post-users-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("renders skeleton rows while the initial fetch is pending", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(5),
      canLoadMore: false,
    });

    const renderPromise = render(
      <template>
        <PostUsersMenu
          @fetchUsers={{fetchUsers}}
          @titleText="Likes"
          @totalUsers={{5}}
        />
      </template>
    );

    await waitFor(".post-users-popup__skeleton-item");

    assert
      .dom(".post-users-popup__skeleton-item")
      .exists(
        { count: 5 },
        "renders one skeleton per pending user up to PAGE_SIZE"
      );

    resolve();
    await renderPromise;
    await settled();

    assert
      .dom(".post-users-popup__skeleton-item")
      .doesNotExist("skeleton rows clear once the fetch resolves");
    assert
      .dom(".post-users-popup__item:not(.post-users-popup__skeleton-item)")
      .exists({ count: 5 }, "renders real user rows after load");
  });

  test("caps skeleton rows at PAGE_SIZE when totalUsers is larger", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(30),
      canLoadMore: true,
    });

    const renderPromise = render(
      <template>
        <PostUsersMenu
          @fetchUsers={{fetchUsers}}
          @titleText="Likes"
          @totalUsers={{200}}
        />
      </template>
    );

    await waitFor(".post-users-popup__skeleton-item");

    assert
      .dom(".post-users-popup__skeleton-item")
      .exists({ count: 30 }, "skeleton count is capped at PAGE_SIZE");

    resolve();
    await renderPromise;
    await settled();
  });

  test("falls back to a small skeleton count when totalUsers is missing", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(2),
      canLoadMore: false,
    });

    const renderPromise = render(
      <template>
        <PostUsersMenu @fetchUsers={{fetchUsers}} @titleText="Likes" />
      </template>
    );

    await waitFor(".post-users-popup__skeleton-item");

    assert
      .dom(".post-users-popup__skeleton-item")
      .exists(
        { count: 3 },
        "still shows a small skeleton fallback when count is unknown"
      );

    resolve();
    await renderPromise;
    await settled();
  });
});
