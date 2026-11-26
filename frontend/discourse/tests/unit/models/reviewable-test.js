import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { PENDING, REJECTED } from "discourse/models/reviewable";

module("Unit | Model | reviewable", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.siteSettings.review_queue_consistent_answers = true;

    // The store reuses a record for a repeated id, so each build needs its own.
    let nextId = 1;
    this.build = (attrs) =>
      getOwner(this)
        .lookup("service:store")
        .createRecord("reviewable", {
          id: nextId++,
          status: PENDING,
          type_source: "core",
          approval_style: true,
          ...attrs,
        });
  });

  test("flaggedReviewableContextQuestion excludes the approval requirement from flag reasons", function (assert) {
    const approval = {
      score_type: { type: "needs_approval", title: "Needs Approval" },
    };
    const spam = { score_type: { type: "spam", title: "Spam" } };
    const question = (...scores) =>
      this.build({ type: "ReviewableFlaggedPost", reviewable_scores: scores })
        .flaggedReviewableContextQuestion;

    assert.strictEqual(question(approval, spam), "Is this post spam?");
    assert.strictEqual(
      question(approval),
      "Is there something wrong with this post?"
    );
  });

  test("pending approvals identify what the moderator is approving", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost", topic: { id: 1 } })
        .userReviewableContextQuestion,
      "Post approval"
    );
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost" })
        .userReviewableContextQuestion,
      "Topic approval"
    );
    assert.strictEqual(
      this.build({ type: "ReviewableUser", signup_approval: true })
        .userReviewableContextQuestion,
      "Account approval"
    );
  });

  test("an already-published post uses the post approval heading", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewablePost" }).userReviewableContextQuestion,
      "Post approval"
    );
  });

  test("userReviewableContextQuestion keeps the spam question for suspect users", function (assert) {
    const reviewable = this.build({
      type: "ReviewableUser",
      reviewable_scores: [{ reason_type: "suspect_user" }],
    });

    assert.strictEqual(
      reviewable.userReviewableContextQuestion,
      "Is this user spam?"
    );
  });

  test("a flagged account under review gets a neutral heading", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewableUser", signup_approval: false })
        .userReviewableContextQuestion,
      "Account review"
    );
  });

  test("userReviewableContextQuestion is absent for resolved items, flags and plugin types without an approval heading", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewableUser", status: REJECTED })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost", status: REJECTED })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({ type: "ReviewableFlaggedPost", approval_style: false })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({
        type: "ReviewablePluginQueue",
        type_source: "a-plugin",
      }).userReviewableContextQuestion,
      null
    );
  });

  test("userReviewableContextQuestion asks for approval without consistent answers", function (assert) {
    this.siteSettings.review_queue_consistent_answers = false;

    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost" })
        .userReviewableContextQuestion,
      "Approve this topic?"
    );
    assert.strictEqual(
      this.build({ type: "ReviewablePost", status: REJECTED })
        .userReviewableContextQuestion,
      "Approve this post?",
      "resolved posts keep their question"
    );
    assert.strictEqual(
      this.build({ type: "ReviewableUser" }).userReviewableContextQuestion,
      "Approve this user?"
    );
  });

  test("answersProblem is false only for plugin types that aren't flags or approval queues", function (assert) {
    assert.true(
      this.build({ type: "ReviewableFlaggedPost", approval_style: false })
        .answersProblem,
      "core flag"
    );
    assert.true(
      this.build({
        type: "ReviewablePluginFlag",
        type_source: "a-plugin",
        approval_style: false,
        created_from_flag: true,
      }).answersProblem,
      "plugin flag"
    );
    assert.true(
      this.build({ type: "ReviewablePluginQueue", type_source: "a-plugin" })
        .answersProblem,
      "plugin approval queue"
    );
    assert.false(
      this.build({
        type: "ReviewablePluginNomination",
        type_source: "a-plugin",
        approval_style: false,
        created_from_flag: false,
      }).answersProblem,
      "plugin nomination"
    );
  });
});
