import {
  fetchUnseenMentions,
  linkSeenMentions
} from "discourse/lib/link-mentions";
import { Promise } from "rsvp";
import pretender from "helpers/create-pretender";

QUnit.module("lib:link-mentions");

QUnit.test("linkSeenMentions replaces users and groups", async assert => {
  pretender.get("/u/is_local_username", () => [
    200,
    { "Content-Type": "application/json" },
    {
      valid: ["valid_user"],
      valid_groups: ["valid_group"],
      mentionable_groups: [
        {
          name: "mentionable_group",
          user_count: 1
        }
      ],
      cannot_see: [],
      max_users_notified_per_group_mention: 100
    }
  ]);

  await fetchUnseenMentions([
    "valid_user",
    "mentionable_group",
    "valid_group",
    "invalid"
  ]);

  let $root = $(`
    <div>
        <span class="mention">@invalid</span>
        <span class="mention">@valid_user</span>
        <span class="mention">@valid_group</span>
        <span class="mention">@mentionable_group</span>
    </div>
  `);

  await linkSeenMentions($root);

  // Ember.Test.registerWaiter is not available here, so we are implementing
  // our own
  await new Promise(resolve => {
    const interval = setInterval(() => {
      if ($("a", $root).length > 0) {
        clearInterval(interval);
        resolve();
      }
    }, 500);
  });

  assert.equal($("a", $root)[0].text, "@valid_user");
  assert.equal($("a", $root)[1].text, "@valid_group");
  assert.equal($("a.notify", $root).text(), "@mentionable_group");
  assert.equal($("span.mention", $root)[0].innerHTML, "@invalid");
});
