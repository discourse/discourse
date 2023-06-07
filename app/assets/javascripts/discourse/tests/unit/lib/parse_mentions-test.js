import { module, test } from "qunit";
import { parseMentionedUsernames } from "discourse/lib/parse-mentions";

module(
  "Unit | Utility | parse-mentions | parseMentionedUsernames",
  function () {
    test("it parses usernames", function (assert) {
      const cooked =
        "<p>" +
        '<a class="mention" href="/u/jeff">@jeff</a> ' +
        '<a class="mention" href="/u/robin">@robin</a> ' +
        '<a class="mention" href="/u/sam">@sam</a>' +
        "</p>";
      const mentions = parseMentionedUsernames(cooked);
      assert.deepEqual(mentions, ["jeff", "robin", "sam"]);
    });

    test("returns an empty array if there are no mentions", function (assert) {
      const mentions = parseMentionedUsernames("<p>No mentions here</p>>");
      assert.equal(mentions.length, 0);
    });
  }
);
