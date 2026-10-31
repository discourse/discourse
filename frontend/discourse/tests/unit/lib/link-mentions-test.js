import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import domFromString from "discourse/lib/dom-from-string";
import {
  fetchUnseenMentions,
  linkSeenMentions,
} from "discourse/lib/link-mentions";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Utility | link-mentions", function (hooks) {
  setupTest(hooks);

  test("linkSeenMentions replaces users and groups", async function (assert) {
    pretender.get("/composer/mentions", () =>
      response({
        users: ["valid_user"],
        user_reasons: {},
        groups: {
          valid_group: { user_count: 1 },
          mentionable_group: { user_count: 1 },
        },
        group_reasons: { valid_group: "not_mentionable" },
        max_users_notified_per_group_mention: 100,
      })
    );

    await fetchUnseenMentions({
      names: ["valid_user", "mentionable_group", "valid_group", "invalid"],
    });

    const root = domFromString(`
      <div>
        <span class="mention">@invalid</span>
        <span class="mention">@valid_user</span>
        <span class="mention">@valid_group</span>
        <span class="mention">@mentionable_group</span>
      </div>
    `)[0];
    await linkSeenMentions(root);

    assert.dom(root.querySelectorAll("a")[0]).hasText("@valid_user");
    assert.dom(root.querySelectorAll("a")[1]).hasText("@valid_group");
    assert
      .dom("a[data-mentionable-user-count]", root)
      .hasText("@mentionable_group");
    assert.dom("span.mention", root).hasHtml("@invalid");
  });

  test("linkSeenMentions does not reuse cached results in another context", async function (assert) {
    let requestCount = 0;
    pretender.get("/composer/mentions", (request) => {
      requestCount++;
      if (request.queryParams.topic_id === "1") {
        return response({
          users: ["pm_user"],
          user_reasons: { pm_user: "private" },
          groups: {},
          group_reasons: {},
          max_users_notified_per_group_mention: 100,
        });
      }
      return response({
        users: ["pm_user"],
        user_reasons: {},
        groups: {},
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });

    await fetchUnseenMentions({ names: ["pm_user"], topicId: 1 });

    const pmPreview = domFromString(
      `<div><span class="mention">@pm_user</span></div>`
    )[0];
    linkSeenMentions(pmPreview, { min_username_length: 2 }, { topicId: 1 });
    assert
      .dom(pmPreview.querySelector("a.mention"))
      .hasAttribute("data-reason", "private");

    // Replying in an unrelated public topic must not reuse the PM context
    const publicPreview = domFromString(
      `<div><span class="mention">@pm_user</span></div>`
    )[0];
    const unseen = linkSeenMentions(
      publicPreview,
      { min_username_length: 2 },
      { topicId: 2 }
    );
    assert.deepEqual(
      unseen,
      ["pm_user"],
      "it invalidates the cached mention in the new context"
    );

    await fetchUnseenMentions({ names: unseen, topicId: 2 });
    linkSeenMentions(publicPreview, { min_username_length: 2 }, { topicId: 2 });

    assert
      .dom(publicPreview.querySelector("a.mention"))
      .exists("the mention is linked again");
    assert
      .dom(publicPreview.querySelector("a.mention"))
      .doesNotHaveAttribute(
        "data-reason",
        "the private reason from the PM context is not reused"
      );
    assert.strictEqual(
      requestCount,
      2,
      "each context validates with its own request"
    );
  });

  test("a response arriving after a context switch does not populate the new context", async function (assert) {
    let resolvePm;
    const pmPending = new Promise((resolve) => (resolvePm = resolve));

    pretender.get("/composer/mentions", (request) => {
      if (request.queryParams.topic_id === "1") {
        return pmPending;
      }
      return response({
        users: ["pm_user"],
        user_reasons: {},
        groups: {},
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });

    // start validating a mention in a PM, then switch to a public topic
    // while the PM request is still pending
    const pmFetch = fetchUnseenMentions({ names: ["pm_user"], topicId: 1 });
    await fetchUnseenMentions({ names: ["pm_user"], topicId: 2 });

    resolvePm(
      response({
        users: ["pm_user"],
        user_reasons: { pm_user: "private" },
        groups: {},
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      })
    );
    await pmFetch;

    const preview = domFromString(
      `<div><span class="mention">@pm_user</span></div>`
    )[0];
    linkSeenMentions(preview, { min_username_length: 2 }, { topicId: 2 });

    assert
      .dom(preview.querySelector("a.mention"))
      .exists("the mention remains linked");
    assert
      .dom(preview.querySelector("a.mention"))
      .doesNotHaveAttribute(
        "data-reason",
        "the late PM response is discarded instead of leaking into the public context"
      );
  });
});
