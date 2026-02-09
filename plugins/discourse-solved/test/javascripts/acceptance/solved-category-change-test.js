import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import { postStreamWithAcceptedAnswerExcerpt } from "../helpers/discourse-solved-helpers";

function solvedTopicFixture() {
  const topic = cloneJSON(postStreamWithAcceptedAnswerExcerpt("an answer"));
  topic.category_id = 100;
  return topic;
}

function unsolvedTopicFixture() {
  const topic = cloneJSON(postStreamWithAcceptedAnswerExcerpt("an answer"));
  topic.category_id = 100;
  topic.accepted_answer = null;
  topic.post_stream.posts.forEach((p) => {
    p.accepted_answer = false;
    p.can_accept_answer = false;
  });
  return topic;
}

const STORAGE_KEY = "discourse-solved-hide-category-change-confirmation";

acceptance("Discourse Solved | Category Change Confirmation", function (needs) {
  needs.user({ admin: true });

  needs.settings({
    solved_enabled: true,
    allow_solved_on_all_topics: false,
  });

  needs.hooks.beforeEach(() => {
    localStorage.removeItem(STORAGE_KEY);
  });

  needs.hooks.afterEach(() => {
    localStorage.removeItem(STORAGE_KEY);
  });

  needs.site({
    categories: [
      {
        id: 100,
        name: "Solved Category",
        slug: "solved-category",
        color: "0088CC",
        text_color: "FFFFFF",
        permission: 1,
        custom_fields: { enable_accepted_answers: "true" },
      },
      {
        id: 200,
        name: "Unsolved Category",
        slug: "unsolved-category",
        color: "FF0000",
        text_color: "FFFFFF",
        permission: 1,
        custom_fields: {},
      },
      {
        id: 300,
        name: "Another Solved Category",
        slug: "another-solved-category",
        color: "00FF00",
        text_color: "FFFFFF",
        permission: 1,
        custom_fields: { enable_accepted_answers: "true" },
      },
    ],
  });

  needs.pretender((server, helper) => {
    server.get("/t/50.json", () => helper.response(solvedTopicFixture()));
    server.get("/t/51.json", () => helper.response(unsolvedTopicFixture()));
    server.get("/t/23.json", () => helper.response(solvedTopicFixture()));
    server.put("/t/test-solved/50", () =>
      helper.response({ basic_topic: { id: 50, title: "Test solved" } })
    );
  });

  test("shows confirmation modal when changing from solved to unsolved category", async function (assert) {
    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .exists("confirmation modal is shown");

    assert
      .dom(".category-change-solved-confirmation-modal .d-modal__title")
      .hasText(i18n("solved.confirm_category_change_solution_title"));
  });

  test("does not show modal when topic has no accepted answer", async function (assert) {
    await visit("/t/test-solved/51");

    await click("#topic-title .d-icon-pencil");

    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .doesNotExist("confirmation modal is not shown");
  });

  test("canceling modal prevents category change", async function (assert) {
    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .exists("confirmation modal is shown");

    await click(
      ".category-change-solved-confirmation-modal .d-modal__footer .btn-transparent"
    );

    assert
      .dom(".category-change-solved-confirmation-modal")
      .doesNotExist("modal is closed");

    assert
      .dom("#topic-title .d-icon-pencil")
      .doesNotExist("still in editing mode");
  });

  test("confirming modal proceeds with category change", async function (assert) {
    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .exists("confirmation modal is shown");

    await click(
      ".category-change-solved-confirmation-modal .d-modal__footer .btn-primary"
    );

    assert
      .dom(".category-change-solved-confirmation-modal")
      .doesNotExist("modal is closed");
  });

  test("does not show modal when changing to another solved category", async function (assert) {
    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(300);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .doesNotExist(
        "confirmation modal is not shown for solved-to-solved change"
      );
  });

  test("respects 'don't show again' preference", async function (assert) {
    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    let categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .exists("confirmation modal is shown");

    await click(".category-change-solution-dont-show-again input");
    await click(
      ".category-change-solved-confirmation-modal .d-modal__footer .btn-primary"
    );

    await visit("/t/test-solved/50");

    await click("#topic-title .d-icon-pencil");

    categoryChooser = selectKit(".title-wrapper .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(200);
    await click("#topic-title .submit-edit");

    assert
      .dom(".category-change-solved-confirmation-modal")
      .doesNotExist("confirmation modal is not shown second time");
  });
});
