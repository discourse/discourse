import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import I18n from "I18n";
import { Promise } from "rsvp";
import { fillIn, triggerEvent } from "@ember/test-helpers";
import { module } from "qunit";

function fetchMembersHandler(channelId, params = {}) {
  if (params.offset === 50) {
    return Promise.resolve([{ user: { id: 3, username: "clara" } }]);
  }

  if (params.offset === 100) {
    return Promise.resolve([]);
  }

  if (!params.username) {
    return Promise.resolve([
      { user: { id: 1, username: "jojo" } },
      { user: { id: 2, username: "bob" } },
    ]);
  }

  if (params.username === "jojo") {
    return Promise.resolve([{ user: { id: 1, username: "jojo" } }]);
  } else {
    return Promise.resolve([]);
  }
}

function setupState(context) {
  context.set("fetchMembersHandler", fetchMembersHandler);
  context.set("channel", fabricators.chatChannel());
  context.channel.set("memberships_count", 2);
}

module(
  "Discourse Chat | Component | chat-channel-members-view",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("no filter", {
      template: hbs`{{chat-channel-members-view channel=channel fetchMembersHandler=fetchMembersHandler}}`,

      beforeEach() {
        this.set("fetchMembersHandler", fetchMembersHandler);
        this.set("channel", fabricators.chatChannel());
        this.channel.set("memberships_count", 2);
      },

      async test(assert) {
        assert.ok(
          exists(".channel-members-view__list-item[data-user-card='jojo']")
        );
        assert.ok(
          exists(".channel-members-view__list-item[data-user-card='bob']")
        );
      },
    });

    componentTest("filter", {
      template: hbs`{{chat-channel-members-view channel=channel fetchMembersHandler=fetchMembersHandler}}`,

      beforeEach() {
        setupState(this);
      },

      async test(assert) {
        await fillIn(".channel-members-view__search-input", "jojo");

        assert.ok(
          exists(".channel-members-view__list-item[data-user-card='jojo']")
        );
        assert.notOk(
          exists(".channel-members-view__list-item[data-user-card='bob']")
        );
      },
    });

    componentTest("filter with no results", {
      template: hbs`{{chat-channel-members-view channel=channel fetchMembersHandler=fetchMembersHandler}}`,

      beforeEach() {
        setupState(this);
      },

      async test(assert) {
        await fillIn(".channel-members-view__search-input", "cat");

        assert.equal(
          query(".channel-members-view__list").innerText.trim(),
          I18n.t("chat.channel.no_memberships_found")
        );

        assert.notOk(
          exists(".channel-members-view__list-item[data-user-card='jojo']")
        );
        assert.notOk(
          exists(".channel-members-view__list-item[data-user-card='bob']")
        );
      },
    });

    componentTest("loading more", {
      template: hbs`{{chat-channel-members-view channel=channel fetchMembersHandler=fetchMembersHandler}}`,

      beforeEach() {
        this.set("fetchMembersHandler", fetchMembersHandler);
        this.set("channel", fabricators.chatChannel());
        this.channel.set("memberships_count", 3);
      },

      async test(assert) {
        await triggerEvent(".channel-members-view__list", "scroll");

        ["jojo", "bob", "clara"].forEach((username) => {
          assert.ok(
            exists(
              `.channel-members-view__list-item[data-user-card='${username}']`
            )
          );
        });

        await triggerEvent(".channel-members-view__list", "scroll");

        ["jojo", "bob", "clara"].forEach((username) => {
          assert.ok(
            exists(
              `.channel-members-view__list-item[data-user-card='${username}']`
            )
          );
        });
      },
    });
  }
);
