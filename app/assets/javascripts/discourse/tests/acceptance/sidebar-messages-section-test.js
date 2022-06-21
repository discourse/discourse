import { test } from "qunit";

import { click, currentURL, visit } from "@ember/test-helpers";

import {
  acceptance,
  exists,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Sidebar - Messages Section - enable_personal_messages disabled",
  function (needs) {
    needs.user({
      experimental_sidebar_enabled: true,
    });

    needs.settings({
      enable_personal_messages: false,
    });

    test("clicking on section header button", async function (assert) {
      await visit("/");

      assert.ok(
        !exists(".sidebar-section-messages"),
        "does not display messages section in sidebar"
      );
    });
  }
);

acceptance(
  "Sidebar - Messages Section - enable_personal_messages enabled",
  function (needs) {
    needs.user({
      experimental_sidebar_enabled: true,
    });

    needs.pretender((server, helper) => {
      [
        "/topics/private-messages-new/:username.json",
        "/topics/private-messages-unread/:username.json",
        "/topics/private-messages-archive/:username.json",
        "/topics/private-messages-sent/:username.json",
        "/topics/private-messages-group/:username/:group_name/new.json",
        "/topics/private-messages-group/:username/:group_name.json",
        "/topics/private-messages-group/:username/:group_name/unread.json",
        "/topics/private-messages-group/:username/:group_name/archive.json",
      ].forEach((url) => {
        server.get(url, () => {
          const topics = [
            { id: 1, posters: [] },
            { id: 2, posters: [] },
            { id: 3, posters: [] },
          ];

          return helper.response({
            topic_list: {
              topics,
            },
          });
        });
      });
    });

    test("clicking on section header button", async function (assert) {
      await visit("/");

      await click(".sidebar-section-messages .sidebar-section-header-button");

      assert.ok(
        exists("#reply-control.private-message"),
        "it opens the composer"
      );
    });

    test("clicking on section header link", async function (assert) {
      await visit("/");
      await click(".sidebar-section-messages .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        `/u/eviltrout/messages`,
        "it should transistion to the user's messages"
      );
    });

    test("personal messages section links", async function (assert) {
      await visit("/");

      assert.ok(
        exists(
          ".sidebar-section-messages .sidebar-section-link-personal-messages-inbox"
        ),
        "displays the personal message inbox link"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link").length,
        1,
        "only displays the personal message inbox link"
      );

      await click(
        ".sidebar-section-messages .sidebar-section-link-personal-messages-inbox"
      );

      assert.ok(
        exists(
          ".sidebar-section-messages .sidebar-section-link-personal-messages-inbox.active"
        ),
        "personal message inbox link is marked as active"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link").length,
        5,
        "expands and displays the links for personal messages"
      );
    });

    ["new", "archive", "sent", "unread"].forEach((type) => {
      test(`${type} personal messages section link`, async function (assert) {
        await visit("/");

        await click(
          ".sidebar-section-messages .sidebar-section-link-personal-messages-inbox"
        );

        await click(
          `.sidebar-section-messages .sidebar-section-link-personal-messages-${type}`
        );

        assert.strictEqual(
          currentURL(),
          `/u/eviltrout/messages/${type}`,
          `it should transition to user's ${type} personal messages`
        );

        assert.strictEqual(
          queryAll(".sidebar-section-messages .sidebar-section-link.active")
            .length,
          2,
          "only two links are marked as active in the sidebar"
        );

        assert.ok(
          exists(
            ".sidebar-section-messages .sidebar-section-link-personal-messages-inbox.active"
          ),
          "personal message inbox link is marked as active"
        );

        assert.ok(
          exists(
            `.sidebar-section-messages .sidebar-section-link-personal-messages-${type}.active`
          ),
          `personal message ${type} link is marked as active`
        );
      });
    });

    test("group messages section links", async function (assert) {
      updateCurrentUser({
        groups: [
          {
            name: "group1",
            has_messages: true,
          },
          {
            name: "group2",
            has_messages: false,
          },
          {
            name: "group3",
            has_messages: true,
          },
        ],
      });

      await visit("/");

      assert.ok(
        exists(
          ".sidebar-section-messages .sidebar-section-link-group-messages-inbox.group1"
        ),
        "displays group1 inbox link"
      );

      assert.ok(
        exists(
          ".sidebar-section-messages .sidebar-section-link-group-messages-inbox.group3"
        ),
        "displays group3 inbox link"
      );

      await visit("/u/eviltrout/messages/group/GrOuP1");

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link").length,
        6,
        "expands and displays the links for group1 group messages"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link.group1")
          .length,
        4,
        "expands the links for group1 group messages"
      );

      await click(
        ".sidebar-section-messages .sidebar-section-link-group-messages-inbox.group3"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link.group1")
          .length,
        1,
        "collapses the links for group1 group messages"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link.group3")
          .length,
        4,
        "expands the links for group3 group messages"
      );
    });

    ["new", "archive", "unread"].forEach((type) => {
      test(`${type} group messages section link`, async function (assert) {
        updateCurrentUser({
          groups: [
            {
              name: "group1",
              has_messages: true,
            },
            {
              name: "group2",
              has_messages: false,
            },
            {
              name: "group3",
              has_messages: true,
            },
          ],
        });

        await visit("/");

        await click(
          `.sidebar-section-messages .sidebar-section-link-group-messages-inbox.group1`
        );

        await click(
          `.sidebar-section-messages .sidebar-section-link-group-messages-${type}.group1`
        );

        assert.strictEqual(
          currentURL(),
          `/u/eviltrout/messages/group/group1/${type}`,
          `it should transition to user's ${type} personal messages`
        );

        assert.strictEqual(
          queryAll(".sidebar-section-messages .sidebar-section-link.active")
            .length,
          2,
          "only two links are marked as active in the sidebar"
        );

        assert.ok(
          exists(
            ".sidebar-section-messages .sidebar-section-link-group-messages-inbox.group1.active"
          ),
          "group1 group message inbox link is marked as active"
        );

        assert.ok(
          exists(
            `.sidebar-section-messages .sidebar-section-link-group-messages-${type}.group1.active`
          ),
          `group1 group message ${type} link is marked as active`
        );
      });
    });

    test("viewing personal message topic with a group the user is a part of", async function (assert) {
      updateCurrentUser({
        groups: [
          {
            name: "foo_group", // based on fixtures
            has_messages: true,
          },
        ],
      });

      await visit("/t/130");

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link").length,
        5,
        "5 section links are displayed"
      );

      assert.strictEqual(
        queryAll(
          ".sidebar-section-messages .sidebar-section-link.personal-messages"
        ).length,
        1,
        "personal messages inbox filter links are not shown"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link.foo_group")
          .length,
        4,
        "foo_group messages inbox filter links are shown"
      );
    });

    test("viewing personal message topic", async function (assert) {
      updateCurrentUser({
        groups: [
          {
            name: "foo_group", // based on fixtures
            has_messages: true,
          },
        ],
      });

      await visit("/t/34");

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link").length,
        6,
        "6 section links are displayed"
      );

      assert.strictEqual(
        queryAll(
          ".sidebar-section-messages .sidebar-section-link.personal-messages"
        ).length,
        5,
        "personal messages inbox filter links are shown"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-messages .sidebar-section-link.foo_group")
          .length,
        1,
        "foo_group messages inbox filter links are not shown"
      );
    });
  }
);
