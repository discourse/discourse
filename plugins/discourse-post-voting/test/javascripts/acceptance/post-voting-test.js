import {
  click,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
const topicList = cloneJSON(discoveryFixtures["/latest.json"]);

function postVotingEnabledTopicResponse() {
  Object.assign(topicResponse.post_stream.posts[0], {
    post_voting_vote_count: 0,
    comments_count: 1,
    post_voting_has_votes: false,

    comments: [
      {
        id: 1,
        user_id: 12345,
        name: "Some Name",
        username: "some_username",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 1</p>",
      },
    ],
  });

  Object.assign(topicResponse.post_stream.posts[1], {
    post_voting_vote_count: 2,
    post_voting_has_votes: true,
    comments_count: 6,
    post_voting_user_voted_direction: "up",

    comments: [
      {
        id: 2,
        user_id: 12345,
        name: "Some Name",
        username: "some_username",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 2</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      },
      {
        id: 3,
        user_id: 12345,
        name: "Some Name",
        username: "some_username",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 3</p>",
        post_voting_vote_count: 3,
        user_voted: false,
      },
      {
        id: 4,
        user_id: 123456,
        name: "Some Name 2 ",
        username: "some_username2",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 4</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      },
      {
        id: 5,
        user_id: 1234567,
        name: "Some Name 3 ",
        username: "some_username3",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 5</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      },
      {
        id: 6,
        user_id: 12345678,
        name: null,
        username: null,
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 6</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      },
    ],
  });

  topicResponse.is_post_voting = true;

  return topicResponse;
}

function postVotingTopicListResponse() {
  // will link to OP
  topicList.topic_list.topics[0].is_post_voting = true;
  topicList.topic_list.topics[0].last_read_post_number =
    topicList.topic_list.topics[0].highest_post_number;

  // will sort by activity
  topicList.topic_list.topics[1].is_post_voting = true;
  topicList.topic_list.topics[1].last_read_post_number =
    topicList.topic_list.topics[1].highest_post_number - 2;

  // will link to last post
  topicList.topic_list.topics[3].is_post_voting = true;
  topicList.topic_list.topics[3].last_read_post_number =
    topicList.topic_list.topics[3].highest_post_number - 1;

  return topicList;
}

let filteredByActivity = false;

function setupPostVoting(needs) {
  needs.settings({
    post_voting_enabled: true,
    min_post_length: 5,
    post_voting_comment_max_raw_length: 50,
    post_voting_enable_likes_on_answers: false,
  });

  needs.hooks.afterEach(function () {
    filteredByActivity = false;
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", (request) => {
      if (request.queryParams.filter === "activity") {
        filteredByActivity = true;
      } else {
        filteredByActivity = false;
      }

      return helper.response(postVotingEnabledTopicResponse());
    });

    server.get("/post_voting/comments", () => {
      return helper.response({
        comments: [
          {
            id: 7,
            user_id: 12345678,
            name: "Some Name 4",
            username: "some_username4",
            created_at: "2022-01-12T08:21:54.175Z",
            cooked: "<p>Test comment 7</p>",
            post_voting_vote_count: 0,
            user_voted: false,
          },
        ],
      });
    });

    server.post("/post_voting/comments", () => {
      return helper.response({
        id: 9,
        user_id: 12345678,
        name: "Some Name 5",
        username: "some_username5",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 9</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      });
    });

    server.delete("/post_voting/comments", () => {
      return helper.response({});
    });

    server.put("/post_voting/comments", () => {
      return helper.response({
        id: 1,
        user_id: 12345,
        name: "Some Name",
        username: "some_username",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>editing this</p>",
        post_voting_vote_count: 0,
        user_voted: false,
      });
    });

    server.post("/post_voting/vote/comment", () => {
      return helper.response({});
    });

    server.delete("/post_voting/vote/comment", () => {
      return helper.response({});
    });

    server.post("/post_voting/vote", () => {
      return helper.response({});
    });

    server.delete("/post_voting/vote", () => {
      return helper.response({});
    });

    server.get("/latest.json", () => {
      return helper.response(postVotingTopicListResponse());
    });
  });
}

acceptance("anon user", function (needs) {
  setupPostVoting(needs);

  test("Viewing comments", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists(
        { count: 1 },
        "displays the right number of comments for the first post"
      );

    assert
      .dom("#post_2 .post-voting-comments__comment")
      .exists(
        { count: 5 },
        "displays the right number of comments for the second post"
      );

    assert
      .dom("#post_2 .post-voting-comments__comment-actions")
      .doesNotExist("does not display comment actions to anon users");

    await click(".post-voting-comments__actions-show-more");

    assert
      .dom("#post_2 .post-voting-comments__comment")
      .exists(
        { count: 6 },
        "displays the right number of comments after loading more"
      );

    assert
      .dom(
        "#post_2 .post-voting-comments #post-voting-comment-6 .post-voting-comments__username"
      )
      .hasText(i18n("post_voting.post.post_voting_comment.user.deleted"));
  });

  test("adding a comment", async function (assert) {
    await visit("/t/280");
    await click(".post-voting-comments__actions-add");

    assert.dom("#login-form").exists("displays the login screen");
  });

  test("voting a comment", async function (assert) {
    await visit("/t/280");
    await click("#post_2 #post-voting-comment-2 .post-voting-button.--upvote");

    assert.dom("#login-form").exists("displays the login screen");
  });
});

acceptance("logged in user", function (needs) {
  setupPostVoting(needs);
  needs.user();

  test("Post Voting features do not leak into non-Post Voting topics", async function (assert) {
    await visit("/t/130");

    assert.dom("#post_1 button.reply").exists("displays the reply button");

    assert
      .dom(".post-voting-answers-header")
      .doesNotExist("does not display the Post Voting answers header");
  });

  test("non Post Voting topics do not have Post Voting specific class on body tag", async function (assert) {
    await visit("/t/130");

    assert
      .dom(document.body)
      .doesNotHaveClass(
        "post-voting-topic",
        "does not append Post Voting specific class on body tag"
      );

    await visit("/t/280");

    assert
      .dom(document.body)
      .hasClass(
        "post-voting-topic",
        "appends Post Voting specific class on body tag"
      );

    await visit("/t/130");

    assert
      .dom(document.body)
      .doesNotHaveClass(
        "post-voting-topic",
        "does not append Post Voting specific class on body tag"
      )
      .doesNotHaveClass(
        "--sort-by-activity",
        "does not append sort-by-activity modifier on body tag"
      );
  });

  test("Post Voting topics has relevant copy on reply button", async function (assert) {
    await visit("/t/280");

    assert
      .dom(".reply.create .d-button-label")
      .hasText(
        i18n("post_voting.topic.answer.label"),
        "displays the correct reply label"
      );
  });

  test("sorting post stream by activity and votes", async function (assert) {
    await visit("/t/280");

    assert
      .dom(".post-voting-answers-header__sort .--votes")
      .hasClass("active", "sort by votes is active by default");

    assert
      .dom(document.body)
      .hasClass(
        "post-voting-topic",
        "appends the right class to body when loading Post Voting topic"
      );

    await click(".post-voting-answers-header__sort .--activity");

    assert.true(
      filteredByActivity,
      "refreshes post stream with the right filter"
    );

    assert
      .dom(document.body)
      .hasClass(
        "--sort-by-activity",
        "appends the sort-by-activity modifier on body when topic is filtered by activity"
      );

    assert
      .dom(".post-voting-answers-header__sort .--activity")
      .hasClass("active", "marks sort by activity as active");

    await click(".post-voting-answers-header__sort .--votes");

    assert
      .dom(".post-voting-answers-header__sort .--votes")
      .hasClass("active", "marks sort by votes as active");

    assert
      .dom(document.body)
      .hasClass(
        "post-voting-topic",
        "keeps the topic class on body when filtered by votes"
      )
      .doesNotHaveClass(
        "--sort-by-activity",
        "removes the sort-by-activity modifier from body"
      );

    assert.false(
      filteredByActivity,
      "removes activity filter from post stream"
    );
  });

  test("reply buttons are hidden in post stream except for the first post", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_1 .reply")
      .exists("reply button is shown for the first post");

    assert
      .dom("#post_2 .reply")
      .doesNotExist("reply button is only shown for the first post");
  });

  test("like buttons are hidden in post stream except for the first post", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_1 .like")
      .exists("like button is shown for the first post");

    assert
      .dom("#post_2 .like")
      .doesNotExist("like button is only shown for the first post");
  });

  test("validations for comment length", async function (assert) {
    await visit("/t/280");
    await click("#post_1 .post-voting-comments__actions-add");

    await fillIn(".post-voting-comments__composer-textarea", "a".repeat(4));

    assert.dom(".post-voting-comments__composer-flash").hasText(
      i18n("post_voting.post.post_voting_comment.composer.too_short", {
        count: 5,
      }),
      "displays the right message about raw length when it is too short"
    );

    assert
      .dom(".post-voting-comments__composer-submit")
      .isDisabled("submit comment button is disabled");

    await fillIn(".post-voting-comments__composer-textarea", "a".repeat(6));

    assert
      .dom(".post-voting-comments__composer-flash")
      .hasText(
        "6/50",
        "displays current/max character count when length is OK"
      );

    assert
      .dom(".post-voting-comments__composer-submit")
      .isEnabled("submit comment button is enabled");

    assert
      .dom(".post-voting-comments__composer-textarea")
      .hasAttribute(
        "maxlength",
        "50",
        "enforces the comment length limit via maxlength"
      );
  });

  test("adding a comment", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists(
        { count: 1 },
        "displays the right number of comments for the first post"
      );

    await click("#post_1 .post-voting-comments__actions-add");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists({ count: 2 }, "loads all comments when composer is expanded");

    await fillIn(
      ".post-voting-comments__composer-textarea",
      "this is some comment"
    );
    await click(".post-voting-comments__composer-submit");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists({ count: 3 }, "should add the new comment");
  });

  test("adding a comment with keyboard shortcut", async function (assert) {
    await visit("/t/280");
    await click("#post_1 .post-voting-comments__actions-add");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists({ count: 2 }, "loads all comments when composer is expanded");

    await fillIn(
      ".post-voting-comments__composer-textarea",
      "this is a new test comment"
    );

    await triggerEvent(".post-voting-comments__composer-submit", "keydown", {
      key: "Enter",
      ctrlKey: true,
    });

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists({ count: 3 }, "should add the new comment");
  });

  test("regular user can't edit other people's comments", async function (assert) {
    updateCurrentUser({ id: 9876, admin: false, moderator: false }); // hasn't commented

    await visit("/t/280");

    assert
      .dom("#post_2 .post-voting-comments__comment-actions")
      .doesNotExist("does not display edit link on other people's comments");
  });

  test("moderator can edit other people's comments", async function (assert) {
    updateCurrentUser({ id: 9876, admin: false, moderator: true }); // hasn't commented

    await visit("/t/280");

    assert
      .dom("#post_2 .post-voting-comments__comment-actions")
      .exists({ count: 5 }, "displays edit link on other people's comments");
  });

  test("admin can edit other people's comments", async function (assert) {
    updateCurrentUser({ id: 9876, admin: true, moderator: false }); // hasn't commented

    await visit("/t/280");

    assert
      .dom("#post_2 .post-voting-comments__comment-actions")
      .exists({ count: 5 }, "displays edit link on other people's comments");
  });

  test("editing a comment", async function (assert) {
    updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

    await visit("/t/280");

    assert
      .dom("#post_1 .post-voting-comments__comment-cooked")
      .hasText(
        "Test comment 1",
        "displays the right content for the given comment"
      );

    await click("#post_1 .post-voting-comments__comment-actions-edit-link");

    await fillIn(".post-voting-comments__composer-textarea", "a".repeat(4));

    assert.dom(".post-voting-comments__composer-flash").hasText(
      i18n("post_voting.post.post_voting_comment.composer.too_short", {
        count: 5,
      }),
      "displays the right message about raw length when it is too short"
    );

    assert
      .dom(".post-voting-comments__comment-editor-submit")
      .isDisabled("submit comment button is disabled");

    await fillIn(
      "#post_1 .post-voting-comments__comment-editor-1 textarea",
      "editing this"
    );

    assert
      .dom(".post-voting-comments__composer-flash")
      .hasText(
        "12/50",
        "displays current/max character count when comment length is OK"
      );

    assert
      .dom(".post-voting-comments__comment-editor-submit")
      .isEnabled("submit comment button is enabled");

    await click(
      "#post_1 .post-voting-comments__comment-editor-1 .post-voting-comments__comment-editor-submit"
    );

    assert
      .dom("#post_1 .post-voting-comments__comment-cooked")
      .hasText(
        "editing this",
        "displays the right content after comment has been edited"
      );

    assert
      .dom("#post_1 .post-voting-comments__comment-editor-1")
      .doesNotExist("hides editor after comment has been edited");
  });

  test("deleting a comment", async function (assert) {
    updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

    await visit("/t/280");

    assert
      .dom("#post_1 .post-voting-comments__comment")
      .exists(
        { count: 1 },
        "displays the right number of comments for the first post"
      );

    await click("#post_1 .post-voting-comments__comment-actions-delete-link");
    await click("button.btn-danger");

    assert
      .dom("#post_1 #post-voting-comment-1")
      .hasClass("--deleted", "adds the right modifier to deleted comment");
  });

  test("deleting a comment after more comments have been loaded", async function (assert) {
    updateCurrentUser({ admin: true });

    await visit("/t/280");

    assert
      .dom("#post_2 .post-voting-comments__comment")
      .exists(
        { count: 5 },
        "displays the right number of comments for the second post"
      );

    await click("#post_2 .post-voting-comments__actions-show-more");

    assert
      .dom("#post_2 .post-voting-comments__comment")
      .exists({ count: 6 }, "appends the loaded comments");

    const comments = document.querySelectorAll(
      "#post_2 .post-voting-comments__comment-actions-delete-link"
    );

    await click(comments[comments.length - 1]);
    await click("button.btn-danger");

    assert
      .dom("#post_2 .post-voting-comments__actions-show-more")
      .doesNotExist(
        "updates the comment count such that show more link is not displayed"
      );

    assert
      .dom("#post_2 #post-voting-comment-7")
      .hasClass("--deleted", "adds the right modifier to deleted comment");
  });

  test("vote count display", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_2 #post-voting-comment-2 .post-voting-comments__vote-count")
      .hasClass("--none", "marks zero vote count with --none modifier")
      .hasText("0", "displays 0 when vote count is zero");

    assert
      .dom("#post_2 #post-voting-comment-3 .post-voting-comments__vote-count")
      .hasText("3", "displays the right vote count");
  });

  test("voting on a comment and removing vote", async function (assert) {
    await visit("/t/280");

    await click("#post_2 #post-voting-comment-2 .post-voting-button.--upvote");

    assert
      .dom("#post_2 #post-voting-comment-2 .post-voting-comments__vote-count")
      .hasText("1", "updates the comment vote count correctly");

    await click("#post_2 #post-voting-comment-2 .post-voting-button.--upvote");

    assert
      .dom("#post_2 #post-voting-comment-2 .post-voting-comments__vote-count")
      .hasClass("--none", "reverts to --none modifier when vote is removed")
      .hasText("0", "displays 0 after vote is removed");
  });

  test("voting on a post and removing vote updates the count reactively", async function (assert) {
    await visit("/t/280");

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("2", "displays the initial post vote count");

    await click("#post_2 .post-voting-button.--upvote");

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("1", "decrements the post vote count after removing upvote");

    assert
      .dom("#post_2 .post-voting-button.--upvote")
      .doesNotHaveClass("--voted", "unhighlights the upvote button");

    await click("#post_2 .post-voting-button.--downvote");

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("0", "decrements the post vote count after downvoting");

    assert
      .dom("#post_2 .post-voting-button.--downvote")
      .hasClass("--voted", "highlights the downvote button");
  });

  test("topic list link overrides work", async function (assert) {
    await visit("/");

    assert
      .dom(".topic-list-item:first-child .raw-topic-link")
      .hasAttribute("href", /\/1$/);

    assert
      .dom(".topic-list-item:nth-child(2) .raw-topic-link")
      .hasAttribute("href", /\?filter=activity$/);

    assert
      .dom(".topic-list-item:nth-child(4) .raw-topic-link")
      .hasAttribute("href", /\/2$/);
  });

  test("receiving user post voted message where current user removed their vote", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      post_voting_vote_count: 0,
      post_voting_has_votes: false,
      post_voting_user_voted_id: 19,
      post_voting_user_voted_direction: null,
    });

    await settled();

    assert
      .dom("#post_2 span.post-voting-post__toggle-voters")
      .hasText("0", "displays the right count");

    assert
      .dom("#post_2 .post-voting-button.--upvote")
      .doesNotHaveClass("--voted", "does not highlight the upvote button");
  });

  test("receiving user post voted message where post no longer has votes", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      post_voting_vote_count: 0,
      post_voting_has_votes: false,
      post_voting_user_voted_id: 280,
      post_voting_user_voted_direction: "down",
    });

    await settled();

    assert
      .dom("#post_2 span.post-voting-post__toggle-voters")
      .hasText("0", "does not render a button to show post voters");
  });

  test("receiving user post voted message where upvotes and downvotes cancel out", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      post_voting_vote_count: 0,
      post_voting_has_votes: true,
      post_voting_user_voted_id: 123456,
      post_voting_user_voted_direction: "up",
    });

    await settled();

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("0", "displays 0 when upvotes and downvotes cancel out");
  });

  test("receiving user post voted message where current user is not the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      post_voting_vote_count: 5,
      post_voting_has_votes: true,
      post_voting_user_voted_id: 123456,
      post_voting_user_voted_direction: "down",
    });

    await settled();

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("5", "displays the right post vote count");

    assert
      .dom("#post_2 .post-voting-button.--upvote")
      .hasClass("--voted", "highlights the upvote button for the current user");

    assert
      .dom("#post_2 .post-voting-button.--downvote")
      .doesNotHaveClass(
        "--voted",
        "does not highlight the downvote button for the current user"
      );
  });

  test("receiving user post voted message where current user is the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      post_voting_vote_count: 5,
      post_voting_has_votes: true,
      post_voting_user_voted_id: 19,
      post_voting_user_voted_direction: "up",
    });

    await settled();

    assert
      .dom("#post_2 .post-voting-post__toggle-voters")
      .hasText("5", "displays the right post vote count");

    assert
      .dom("#post_2 .post-voting-button.--upvote")
      .hasClass("--voted", "highlights the upvote button for the current user");
  });

  test("receiving post commented message when comment has already been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_commented",
      id: topicResponse.post_stream.posts[0].id,
      comments_count: 1,
      comment: topicResponse.post_stream.posts[0]["comments"][0],
    });

    await settled();

    assert
      .dom("#post_1 #post-voting-comment-5678")
      .doesNotExist(
        "does not append comment when comment has already been loaded"
      );
  });

  test("receiving post commented message for a comment created by the current user", async function (assert) {
    updateCurrentUser({ id: 12345 });

    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_commented",
      id: topicResponse.post_stream.posts[0].id,
      comments_count: 2,
      comment: {
        id: 5678,
        user_id: 12345,
        name: "Some Commenter",
        username: "some_commenter",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment ABC</p>",
      },
    });

    await settled();

    assert
      .dom("#post_1 #post-voting-comment-5678")
      .doesNotExist("does not append comment");
  });

  test("receiving post commented message when there are no more comments to load ", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_commented",
      id: topicResponse.post_stream.posts[0].id,
      comments_count: 2,
      comment: {
        id: 5678,
        user_id: 12345,
        name: "Some Commenter",
        username: "some_commenter",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment ABC</p>",
      },
    });

    await settled();

    assert
      .dom("#post_1 #post-voting-comment-5678")
      .includesText("Test comment ABC", "appends comment to comments stream");
  });

  test("receiving post commented message when there are more comments to load", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_commented",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 7,
      comment: {
        id: 5678,
        user_id: 12345,
        name: "Some Commenter",
        username: "some_commenter",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment ABC</p>",
      },
    });

    await settled();

    assert
      .dom("#post_2 #post-voting-comment-5678")
      .doesNotExist(
        "does not append comment when there are more comments to load"
      );

    assert
      .dom("#post_2 .post-voting-comments__actions-show-more")
      .exists("updates the comments count to reflect the new comment");
  });

  test("receiving post comment trashed message for a comment that has not been loaded ", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_comment_trashed",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 5,
      comment_id: 12345,
    });

    await settled();

    assert
      .dom("#post_2 .post-voting-comments__actions-show-more")
      .doesNotExist("removes the show more comments link");
  });

  test("receiving post comment trashed message for a comment that has been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_comment_trashed",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 5,
      comment_id: topicResponse.post_stream.posts[1].comments[0].id,
    });

    await settled();

    assert
      .dom("#post_2 #post-voting-comment-2")
      .hasClass("--deleted", "adds the right modifier to the comment");
  });

  test("receiving post comment edited message for a comment that has been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "post_voting_post_comment_edited",
      id: topicResponse.post_stream.posts[0].id,
      comment_id: topicResponse.post_stream.posts[0].comments[0].id,
      comment_raw: "this is a new comment raw",
      comment_cooked: "<p>this is a new comment cooked</p>",
    });

    await settled();

    assert
      .dom(
        "#post_1 #post-voting-comment-1 .post-voting-comments__comment-cooked"
      )
      .hasText(
        "this is a new comment cooked",
        "updates the content of the comment"
      );

    await click(
      "#post_1 #post-voting-comment-1 .post-voting-comments__comment-actions-edit-link"
    );

    assert
      .dom(
        "#post_1 #post-voting-comment-1 .post-voting-comments__composer textarea"
      )
      .hasValue(
        "this is a new comment raw",
        "updates the content of the comment editor"
      );
  });
});
