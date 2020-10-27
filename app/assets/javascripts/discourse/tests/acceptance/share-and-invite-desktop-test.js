import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Share and Invite modal - desktop", function (needs) {
  needs.user();

  test("Topic footer button", async (assert) => {
    await visit("/t/internationalization-localization/280");

    assert.ok(
      exists("#topic-footer-button-share-and-invite"),
      "the button exists"
    );

    await click("#topic-footer-button-share-and-invite");

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

    await click(".share-and-invite.modal .modal-tab.invite");

    assert.ok(
      exists(
        ".share-and-invite.modal .modal-panel.invite .send-invite:disabled"
      ),
      "send invite button is disabled"
    );

    assert.ok(
      exists(
        ".share-and-invite.modal .modal-panel.invite .generate-invite-link:disabled"
      ),
      "generate invite button is disabled"
    );
  });

  test("Post date link", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#post_2 .post-info.post-date a");

    assert.ok(exists("#share-link"), "it shows the share modal");
  });
});

acceptance("Share url with badges disabled - desktop", function (needs) {
  needs.user();
  needs.settings({ enable_badges: false });
  test("topic footer button - badges disabled - desktop", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-share-and-invite");

    assert.notOk(
      find(".share-and-invite.modal .modal-panel.share .topic-share-url")
        .val()
        .includes("?u=eviltrout"),
      "it doesn't add the username param when badges are disabled"
    );
  });
});
