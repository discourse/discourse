import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

acceptance("Discourse Solved | Move Solution Post", function (needs) {
  needs.user({ admin: true });

  needs.settings({
    solved_enabled: true,
    allow_solved_on_all_topics: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/12.json", () =>
      helper.response(postStreamWithAcceptedAnswerExcerpt(null))
    );
  });

  needs.hooks.beforeEach(() => {
    localStorage.removeItem("discourse-solved-hide-move-confirmation");
  });

  needs.hooks.afterEach(() => {
    localStorage.removeItem("discourse-solved-hide-move-confirmation");
  });

  test("shows confirmation modal when moving a solved post", async function (assert) {
    await visit("/t/without-excerpt/12");

    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click("#post_2 .select-post");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".move-solution-confirmation-modal")
      .exists("Confirmation modal is shown");

    assert
      .dom(".move-solution-confirmation-modal .d-modal__title")
      .hasText(
        i18n("solved.confirm_move_solution_title"),
        "Modal has correct title"
      );

    assert
      .dom(".move-solution-confirmation-modal .d-modal__footer .btn-primary")
      .exists("Confirm button exists");

    assert
      .dom(".move-solution-confirmation-modal .d-modal__footer .btn-default")
      .exists("Cancel button exists");
  });

  test("canceling the confirmation modal does not open move-to-topic modal", async function (assert) {
    await visit("/t/without-excerpt/12");

    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click("#post_2 .select-post");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".move-solution-confirmation-modal")
      .exists("Confirmation modal is shown");

    await click(
      ".move-solution-confirmation-modal .d-modal__footer .btn-default"
    );

    assert
      .dom(".move-solution-confirmation-modal")
      .doesNotExist("Confirmation modal is closed");

    assert
      .dom("#choosing-topic")
      .doesNotExist("Move-to-topic modal is not shown");
  });

  test("does not show confirmation modal for non-solved posts", async function (assert) {
    await visit("/t/without-excerpt/12");

    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click("#post_1 .select-post");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".move-solution-confirmation-modal")
      .doesNotExist("Confirmation modal is not shown");

    assert
      .dom("#choosing-topic")
      .exists("Move-to-topic modal is shown directly");
  });

  test("respects 'don't show again' preference", async function (assert) {
    await visit("/t/without-excerpt/12");

    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click("#post_2 .select-post");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".move-solution-confirmation-modal")
      .exists("Confirmation modal is shown");

    await click(".move-solution-dont-show-again input");
    await click(
      ".move-solution-confirmation-modal .d-modal__footer .btn-primary"
    );

    assert.dom("#choosing-topic").exists("Move-to-topic modal is shown");

    await click("#choosing-topic .modal-close");

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".move-solution-confirmation-modal")
      .doesNotExist("Confirmation modal is not shown second time");

    assert
      .dom("#choosing-topic")
      .exists("Move-to-topic modal is shown directly");
  });
});
