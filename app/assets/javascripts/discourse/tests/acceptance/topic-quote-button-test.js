import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function selectText(selector) {
  const range = document.createRange();
  const node = document.querySelector(selector);
  range.selectNodeContents(node);

  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
}

acceptance("Topic - Quote button - logged in", function (needs) {
  needs.user();
  needs.settings({
    share_quote_visibility: "anonymous",
    share_quote_buttons: "twitter|email",
  });

  test("Does not show the quote share buttons by default", async (assert) => {
    await visit("/t/internationalization-localization/280");
    selectText("#post_5 blockquote");
    assert.ok(exists(".insert-quote"), "it shows the quote button");
    assert.equal(
      find(".quote-sharing").length,
      0,
      "it does not show quote sharing"
    );
  });

  test("Shows quote share buttons with the right site settings", async function (assert) {
    this.siteSettings.share_quote_visibility = "all";

    await visit("/t/internationalization-localization/280");
    selectText("#post_5 blockquote");

    assert.ok(exists(".quote-sharing"), "it shows the quote sharing options");
    assert.ok(
      exists(`.quote-sharing .btn[title='${I18n.t("share.twitter")}']`),
      "it includes the twitter share button"
    );
    assert.ok(
      exists(`.quote-sharing .btn[title='${I18n.t("share.email")}']`),
      "it includes the email share button"
    );
  });
});

acceptance("Topic - Quote button - anonymous", function (needs) {
  needs.settings({
    share_quote_visibility: "anonymous",
    share_quote_buttons: "twitter|email",
  });

  test("Shows quote share buttons with the right site settings", async function (assert) {
    await visit("/t/internationalization-localization/280");
    selectText("#post_5 blockquote");

    assert.ok(find(".quote-sharing"), "it shows the quote sharing options");
    assert.ok(
      exists(`.quote-sharing .btn[title='${I18n.t("share.twitter")}']`),
      "it includes the twitter share button"
    );
    assert.ok(
      exists(`.quote-sharing .btn[title='${I18n.t("share.email")}']`),
      "it includes the email share button"
    );
    assert.equal(
      find(".insert-quote").length,
      0,
      "it does not show the quote button"
    );
  });

  test("Shows single share button when site setting only has one item", async function (assert) {
    this.siteSettings.share_quote_buttons = "twitter";

    await visit("/t/internationalization-localization/280");
    selectText("#post_5 blockquote");

    assert.ok(exists(".quote-sharing"), "it shows the quote sharing options");
    assert.ok(
      exists(`.quote-sharing .btn[title='${I18n.t("share.twitter")}']`),
      "it includes the twitter share button"
    );
    assert.equal(
      find(".quote-share-label").length,
      0,
      "it does not show the Share label"
    );
  });

  test("Shows nothing when visibility is disabled", async function (assert) {
    this.siteSettings.share_quote_visibility = "none";

    await visit("/t/internationalization-localization/280");
    selectText("#post_5 blockquote");

    assert.equal(
      find(".quote-sharing").length,
      0,
      "it does not show quote sharing"
    );

    assert.equal(
      find(".insert-quote").length,
      0,
      "it does not show the quote button"
    );
  });
});
