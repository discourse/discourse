import {
  fetchUnseenMentions,
  linkSeenMentions,
} from "discourse/lib/link-mentions";
import { module, test } from "qunit";
import { Promise } from "rsvp";
import pretender from "discourse/tests/helpers/create-pretender";
import domFromString from "discourse-common/lib/dom-from-string";

module("Unit | Utility | link-mentions", function () {
  test("linkSeenMentions replaces users and groups", async function (assert) {
    pretender.get("/u/is_local_username", () => [
      200,
      { "Content-Type": "application/json" },
      {
        valid: ["valid_user"],
        valid_groups: ["valid_group"],
        mentionable_groups: [
          {
            name: "mentionable_group",
            user_count: 1,
          },
        ],
        cannot_see: [],
        max_users_notified_per_group_mention: 100,
      },
    ]);

    await fetchUnseenMentions([
      "valid_user",
      "mentionable_group",
      "valid_group",
      "invalid",
    ]);

    const root = domFromString(`
      <div>
        <span class="mention">@invalid</span>
        <span class="mention">@valid_user</span>
        <span class="mention">@valid_group</span>
        <span class="mention">@mentionable_group</span>
      </div>
    `)[0];
    await linkSeenMentions(root);

    // Ember.Test.registerWaiter is not available here, so we are implementing
    // our own
    await new Promise((resolve) => {
      const interval = setInterval(() => {
        if (root.querySelectorAll("a").length > 0) {
          clearInterval(interval);
          resolve();
        }
      }, 500);
    });

    assert.strictEqual(root.querySelector("a").innerText, "@valid_user");
    assert.strictEqual(root.querySelectorAll("a")[1].innerText, "@valid_group");
    assert.strictEqual(
      root.querySelector("a.notify").innerText,
      "@mentionable_group"
    );
    assert.strictEqual(
      root.querySelector("span.mention").innerHTML,
      "@invalid"
    );
  });
});
