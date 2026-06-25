import { render, settled, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import UsersPopup from "discourse/components/user/users-popup";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";

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

function renderMenu({ fetchUsers, totalUsers, onReset = () => {} }) {
  return render(
    <template>
      <UsersPopup
        @fetchUsers={{fetchUsers}}
        @titleText="Likes"
        @totalUsers={{totalUsers}}
      >
        <:header as |reset|>{{onReset reset}}</:header>
      </UsersPopup>
    </template>
  );
}

module("Integration | Component | User | UsersPopup", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableLoadMoreObserver();
    this.observations = stubIntersectionObserver();
  });

  hooks.afterEach(function () {
    disableLoadMoreObserver();
  });

  test("renders skeleton rows while the initial fetch is pending", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(5),
      canLoadMore: false,
    });

    const renderPromise = renderMenu({ fetchUsers, totalUsers: 5 });

    await waitFor(".users-popup__skeleton-item");

    assert
      .dom(".users-popup__skeleton-item")
      .exists(
        { count: 5 },
        "renders one skeleton per pending user up to PAGE_SIZE"
      );

    resolve();
    await renderPromise;
    await settled();

    assert
      .dom(".users-popup__skeleton-item")
      .doesNotExist("skeleton rows clear once the fetch resolves");
    assert
      .dom(".users-popup__item:not(.users-popup__skeleton-item)")
      .exists({ count: 5 }, "renders real user rows after load");
  });

  test("caps skeleton rows at PAGE_SIZE when totalUsers is larger", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(30),
      canLoadMore: true,
    });

    const renderPromise = renderMenu({ fetchUsers, totalUsers: 200 });

    await waitFor(".users-popup__skeleton-item");

    assert
      .dom(".users-popup__skeleton-item")
      .exists({ count: 30 }, "skeleton count is capped at PAGE_SIZE");

    resolve();
    await renderPromise;
    await settled();
  });

  test("does not fall back to skeleton rows when load more starts with every known user loaded", async function (assert) {
    let fetchCallCount = 0;
    let resolveSecondFetch;
    const secondFetchPromise = new Promise((resolve) => {
      resolveSecondFetch = resolve;
    });
    const fetchUsers = () => {
      fetchCallCount++;

      if (fetchCallCount === 1) {
        return Promise.resolve({
          users: makeUsers(30),
          canLoadMore: true,
        });
      }

      return secondFetchPromise;
    };

    await renderMenu({ fetchUsers, totalUsers: 30 });

    assert
      .dom(".users-popup__item:not(.users-popup__skeleton-item)")
      .exists({ count: 30 }, "renders the initially loaded full page");

    const triggerPromise =
      this.observations[this.observations.length - 1]?.trigger();
    await waitUntil(() => fetchCallCount === 2);

    assert
      .dom(".users-popup__skeleton-item")
      .doesNotExist(
        "does not render fallback skeleton rows when totalUsers has already been reached"
      );

    resolveSecondFetch({ users: [], canLoadMore: false });
    await triggerPromise;
    await settled();
  });

  test("resets scroll position when the user list is reloaded", async function (assert) {
    const fetchUsers = () =>
      Promise.resolve({ users: makeUsers(3), canLoadMore: false });

    let resetAndReload;
    await renderMenu({
      fetchUsers,
      onReset: (fn) => (resetAndReload = fn),
    });

    const body = document.querySelector(".users-popup__body");
    body.style.cssText = "max-height: 20px; overflow-y: auto";
    body.scrollTop = 50;

    await resetAndReload();

    assert.strictEqual(body.scrollTop, 0, "scrollTop is reset after reload");
  });

  test("falls back to a small skeleton count when totalUsers is missing", async function (assert) {
    const { fetchUsers, resolve } = deferredFetch({
      users: makeUsers(2),
      canLoadMore: false,
    });

    const renderPromise = renderMenu({ fetchUsers });

    await waitFor(".users-popup__skeleton-item");

    assert
      .dom(".users-popup__skeleton-item")
      .exists(
        { count: 3 },
        "still shows a small skeleton fallback when count is unknown"
      );

    resolve();
    await renderPromise;
    await settled();
  });

  test("can transform the display name via user-list-display-name transformer", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = false;

    withPluginApi((api) => {
      api.registerValueTransformer(
        "user-list-display-name",
        ({ value, context }) => {
          if (context.user.id === 1) {
            return "Custom Name";
          }
          return value;
        }
      );
    });

    const fetchUsers = () =>
      Promise.resolve({ users: makeUsers(2), canLoadMore: false });

    await renderMenu({ fetchUsers });

    assert
      .dom(".users-popup__item:nth-child(1) .users-popup__name")
      .hasText("Custom Name", "first user has custom name");
    assert
      .dom(".users-popup__item:nth-child(2) .users-popup__name")
      .hasText("User 2", "second user has default name");
  });

  test("can transform the username via user-list-display-username transformer", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = false;

    withPluginApi((api) => {
      api.registerValueTransformer(
        "user-list-display-username",
        ({ value, context }) => {
          if (context.user.id === 1) {
            return "custom_username";
          }
          return value;
        }
      );
    });

    const fetchUsers = () =>
      Promise.resolve({ users: makeUsers(2), canLoadMore: false });

    await renderMenu({ fetchUsers });

    assert
      .dom(".users-popup__item:nth-child(1) .users-popup__username")
      .hasText("@custom_username", "first user has custom username");
    assert
      .dom(".users-popup__item:nth-child(2) .users-popup__username")
      .hasText("@u2", "second user has default username");
  });
});
