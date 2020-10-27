import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Share and Invite modal - mobile", function (needs) {
  needs.user();
  needs.mobileView();

  test("Topic footer mobile button", async (assert) => {
    await visit("/t/internationalization-localization/280");

    assert.ok(
      !exists("#topic-footer-button-share-and-invite"),
      "the button doesn’t exist"
    );

    const subject = selectKit(".topic-footer-mobile-dropdown");
    await subject.expand();
    await subject.selectRowByValue("share-and-invite");

    assert.ok(exists(".share-and-invite.modal"), "it shows the modal");

    assert.ok(
      exists(".share-and-invite.modal .modal-tab.share"),
      "it shows the share tab"
    );

    assert.ok(
      exists(".share-and-invite.modal .modal-tab.share.is-active"),
      "it activates the share tab by default"
    );

    assert.ok(
      exists(".share-and-invite.modal .modal-tab.invite"),
      "it shows the invite tab"
    );

    assert.equal(
      find(".share-and-invite.modal .modal-panel.share .title").text(),
      "Topic: Internationalization / localization",
      "it shows the topic title"
    );

    assert.ok(
      find(".share-and-invite.modal .modal-panel.share .topic-share-url")
        .val()
        .includes("/t/internationalization-localization/280?u=eviltrout"),
      "it shows the topic sharing url"
    );

    assert.ok(
      find(".share-and-invite.modal .social-link").length > 1,
      "it shows social sources"
    );
  });

  test("Post date link", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#post_2 .post-info.post-date a");

    assert.ok(exists("#share-link"), "it shows the share modal");
  });
});

acceptance("Share url with badges disabled - mobile", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({
    enable_badges: false,
  });
  test("topic footer button - badges disabled - mobile", async (assert) => {
    await visit("/t/internationalization-localization/280");

    const subject = selectKit(".topic-footer-mobile-dropdown");
    await subject.expand();
    await subject.selectRowByValue("share-and-invite");

    assert.notOk(
      find(".share-and-invite.modal .modal-panel.share .topic-share-url")
        .val()
        .includes("?u=eviltrout"),
      "it doesn't add the username param when badges are disabled"
    );
  });
});
