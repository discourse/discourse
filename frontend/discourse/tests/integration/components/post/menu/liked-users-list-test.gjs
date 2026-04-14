import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LikedUsersList from "discourse/components/post/menu/liked-users-list";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const TOTAL_USERS = 200;
const PAGE_SIZE = 60;

function userAttrs(id) {
  return {
    id,
    username: `user${id}`,
    username_lower: `user${id}`,
    avatar_template: `/user_avatar/default/user${id}/{size}/1.png`,
  };
}

function usersFrom(start, count) {
  return Array.from({ length: count }, (_, index) => userAttrs(start + index));
}

module(
  "Integration | Component | Post | Menu | LikedUsersList",
  function (hooks) {
    setupRenderingTest(hooks);

    test("expands liked users and loads more pages", async function (assert) {
      const requestPages = [];

      pretender.get("/post_action_users", (request) => {
        const page = parseInt(request.queryParams.page || "0", 10);
        const start = page * PAGE_SIZE + 1;
        const count = Math.min(PAGE_SIZE, TOTAL_USERS - (start - 1));
        const payload = {
          post_action_users: usersFrom(start, count),
          total_rows_post_action_users: TOTAL_USERS,
        };

        requestPages.push(page);

        if (start - 1 + count < TOTAL_USERS) {
          payload.load_more_post_action_users = `/post_action_users?id=123&post_action_type_id=2&page=${
            page + 1
          }&limit=${PAGE_SIZE}`;
        }

        return response(payload);
      });

      this.post = {
        id: 123,
        likeCount: TOTAL_USERS,
        yours: false,
        showLike: false,
      };

      await render(
        <template><LikedUsersList @post={{this.post}} /><DMenus /></template>
      );

      await click(".fk-d-menu__trigger");

      assert.deepEqual(requestPages, [0]);
      assert.dom(".liked-users-list__avatar").exists({ count: 20 });
      assert.dom(".liked-users-list__show-more-button").hasText("Show more…");
      const menuContent = document.querySelector(
        ".liked-users-list-menu .fk-d-menu__inner-content"
      );
      assert.strictEqual(getComputedStyle(menuContent).overflowX, "visible");
      assert.strictEqual(getComputedStyle(menuContent).overflowY, "visible");

      await click(".liked-users-list__show-more-button");

      assert.deepEqual(requestPages, [0]);
      assert.dom(".liked-users-list__avatar").exists({ count: 40 });
      assert.dom(".liked-users-list__show-more-button").hasText("Show more…");

      await click(".liked-users-list__show-more-button");

      assert.deepEqual(requestPages, [0, 1]);
      assert.dom(".liked-users-list__avatar").exists({ count: 80 });
      assert.dom(".liked-users-list__show-more-button").hasText("Show more…");

      await click(".liked-users-list__show-more-button");

      assert.deepEqual(requestPages, [0, 1, 2]);
      assert.dom(".liked-users-list__avatar").exists({ count: 140 });
      assert.dom(".liked-users-list__show-more-button").hasText("Show more…");

      await click(".liked-users-list__show-more-button");

      assert.deepEqual(requestPages, [0, 1, 2, 3]);
      assert.dom(".liked-users-list__avatar").exists({ count: TOTAL_USERS });
      assert.dom(".liked-users-list__show-more-button").doesNotExist();
      assert.dom(".liked-users-list__show-fewer-button").doesNotExist();
    });

    test("shows more users when all likes fit in one response", async function (assert) {
      let requestCount = 0;

      pretender.get("/post_action_users", () => {
        requestCount += 1;

        return response({
          post_action_users: usersFrom(1, 30),
        });
      });

      this.post = {
        id: 123,
        likeCount: 30,
        yours: false,
        showLike: false,
      };

      await render(
        <template><LikedUsersList @post={{this.post}} /><DMenus /></template>
      );

      await click(".fk-d-menu__trigger");

      assert.strictEqual(requestCount, 1);
      assert.dom(".liked-users-list__avatar").exists({ count: 20 });
      assert.dom(".liked-users-list__show-more-button").hasText("Show more…");
      assert
        .dom(".liked-users-list__list")
        .hasClass("liked-users-list__list--fixed-grid");

      await click(".liked-users-list__show-more-button");

      assert.strictEqual(requestCount, 1);
      assert.dom(".liked-users-list__avatar").exists({ count: 30 });
      assert.dom(".liked-users-list__show-more-button").doesNotExist();
    });

    test("shows the fetched list count inside the popover", async function (assert) {
      pretender.get("/post_action_users", () =>
        response({
          post_action_users: usersFrom(1, 2),
        })
      );

      this.post = {
        id: 123,
        likeCount: 3,
        yours: false,
        showLike: false,
      };

      await render(
        <template><LikedUsersList @post={{this.post}} /><DMenus /></template>
      );

      assert.dom(".fk-d-menu__trigger").hasText("3");

      await click(".fk-d-menu__trigger");

      assert.dom(".liked-users-list__avatar").exists({ count: 2 });
      assert.dom(".liked-users-list__count").hasText("2");
    });

    test("keeps short liked user lists content-sized", async function (assert) {
      pretender.get("/post_action_users", () =>
        response({
          post_action_users: usersFrom(1, 1),
          total_rows_post_action_users: 1,
        })
      );

      this.post = {
        id: 123,
        likeCount: 1,
        yours: false,
        showLike: false,
      };

      await render(
        <template><LikedUsersList @post={{this.post}} /><DMenus /></template>
      );

      await click(".fk-d-menu__trigger");

      assert.dom(".liked-users-list__avatar").exists({ count: 1 });
      assert.dom(".liked-users-list__show-more-button").doesNotExist();
      assert
        .dom(".liked-users-list__list")
        .doesNotHaveClass("liked-users-list__list--fixed-grid");
    });
  }
);
