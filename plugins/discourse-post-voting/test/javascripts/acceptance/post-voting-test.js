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

function setupPostVoting(needs, postStreamMode) {
  needs.settings({
    post_voting_enabled: true,
    min_post_length: 5,
    post_voting_comment_max_raw_length: 50,
    post_voting_enable_likes_on_answers: false,
    glimmer_post_stream_mode: postStreamMode,
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

    server.get("/latest.json", () => {
      return helper.response(postVotingTopicListResponse());
    });
  });
}

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Post Voting - anon user (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      setupPostVoting(needs, postStreamMode);

      test("Viewing comments", async function (assert) {
        await visit("/t/280");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists(
            { count: 1 },
            "displays the right number of comments for the first post"
          );

        assert
          .dom("#post_2 .post-voting-comment")
          .exists(
            { count: 5 },
            "displays the right number of comments for the second post"
          );

        await click(".post-voting-comments-menu-show-more-link");

        assert
          .dom("#post_2 .post-voting-comment")
          .exists(
            { count: 6 },
            "displays the right number of comments after loading more"
          );

        assert
          .dom(
            "#post_2 .post-voting-comments #post-voting-comment-6 .post-voting-comment-info-username"
          )
          .hasText(i18n("post_voting.post.post_voting_comment.user.deleted"));
      });

      test("adding a comment", async function (assert) {
        await visit("/t/280");
        await click(".post-voting-comment-add-link");

        assert.dom("#login-form").exists("displays the login screen");
      });

      test("voting a comment", async function (assert) {
        await visit("/t/280");
        await click(
          "#post_2 #post-voting-comment-2 .post-voting-button-upvote"
        );

        assert.dom("#login-form").exists("displays the login screen");
      });
    }
  );

  acceptance(
    `Discourse Post Voting - logged in user (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      setupPostVoting(needs, postStreamMode);
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
          .dom(".post-voting-answers-headers-sort-votes")
          .isDisabled("sort by votes button is disabled by default");

        assert
          .dom(document.body)
          .hasClass(
            "post-voting-topic",
            "appends the right class to body when loading Post Voting topic"
          );

        await click(".post-voting-answers-headers-sort-activity");

        assert.true(
          filteredByActivity,
          "refreshes post stream with the right filter"
        );

        assert
          .dom(document.body)
          .hasClass(
            "post-voting-topic-sort-by-activity",
            "appends the right class to body when topic is filtered by activity"
          );

        assert
          .dom(".post-voting-answers-headers-sort-activity")
          .isDisabled("disabled sort by activity button");

        await click(".post-voting-answers-headers-sort-votes");

        assert
          .dom(".post-voting-answers-headers-sort-votes")
          .isDisabled("disables sort by votes button");

        assert
          .dom(document.body)
          .hasClass(
            "post-voting-topic",
            "appends the right class to body when topic is filtered by votes"
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
        await click("#post_1 .post-voting-comment-add-link");

        await fillIn(".post-voting-comment-composer-textarea", "a".repeat(4));

        assert.dom(".post-voting-comment-composer-flash").hasText(
          i18n("post_voting.post.post_voting_comment.composer.too_short", {
            count: 5,
          }),
          "displays the right message about raw length when it is too short"
        );

        assert
          .dom(".post-voting-comments-menu-composer-submit")
          .isDisabled("submit comment button is disabled");

        await fillIn(".post-voting-comment-composer-textarea", "a".repeat(6));

        assert.dom(".post-voting-comment-composer-flash").hasText(
          i18n("post_voting.post.post_voting_comment.composer.length_ok", {
            count: 44,
          }),
          "displays the right message about raw length when it is OK"
        );

        assert
          .dom(".post-voting-comments-menu-composer-submit")
          .isEnabled("submit comment button is enabled");

        await fillIn(".post-voting-comment-composer-textarea", "a".repeat(51));

        assert.dom(".post-voting-comment-composer-flash").hasText(
          i18n("post_voting.post.post_voting_comment.composer.too_long", {
            count: 50,
          }),
          "displays the right message about raw length when it is too long"
        );

        assert
          .dom(".post-voting-comments-menu-composer-submit")
          .isDisabled("submit comment button is disabled");
      });

      test("adding a comment", async function (assert) {
        await visit("/t/280");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists(
            { count: 1 },
            "displays the right number of comments for the first post"
          );

        await click("#post_1 .post-voting-comment-add-link");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists({ count: 2 }, "loads all comments when composer is expanded");

        await fillIn(
          ".post-voting-comment-composer-textarea",
          "this is some comment"
        );
        await click(".post-voting-comments-menu-composer-submit");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists({ count: 3 }, "should add the new comment");
      });

      test("adding a comment with keyboard shortcut", async function (assert) {
        await visit("/t/280");
        await click("#post_1 .post-voting-comment-add-link");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists({ count: 2 }, "loads all comments when composer is expanded");

        await fillIn(
          ".post-voting-comment-composer-textarea",
          "this is a new test comment"
        );

        await triggerEvent(
          ".post-voting-comments-menu-composer-submit",
          "keydown",
          {
            key: "Enter",
            ctrlKey: true,
          }
        );

        assert
          .dom("#post_1 .post-voting-comment")
          .exists({ count: 3 }, "should add the new comment");
      });

      test("editing a comment", async function (assert) {
        updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

        await visit("/t/280");

        assert
          .dom("#post_1 .post-voting-comment-cooked")
          .hasText(
            "Test comment 1",
            "displays the right content for the given comment"
          );

        await click("#post_1 .post-voting-comment-actions-edit-link");

        await fillIn(".post-voting-comment-composer-textarea", "a".repeat(4));

        assert.dom(".post-voting-comment-composer-flash").hasText(
          i18n("post_voting.post.post_voting_comment.composer.too_short", {
            count: 5,
          }),
          "displays the right message about raw length when it is too short"
        );

        assert
          .dom(".post-voting-comment-editor-submit")
          .isDisabled("submit comment button is disabled");

        await fillIn(
          "#post_1 .post-voting-comment-editor-1 textarea",
          "editing this"
        );

        assert.dom(".post-voting-comment-composer-flash").hasText(
          i18n("post_voting.post.post_voting_comment.composer.length_ok", {
            count: 38,
          }),
          "displays the right message when comment length is OK"
        );

        assert
          .dom(".post-voting-comment-editor-submit")
          .isEnabled("submit comment button is enabled");

        await click(
          "#post_1 .post-voting-comment-editor-1 .post-voting-comment-editor-submit"
        );

        assert
          .dom("#post_1 .post-voting-comment-cooked")
          .hasText(
            "editing this",
            "displays the right content after comment has been edited"
          );

        assert
          .dom("#post_1 .post-voting-comment-editor-1")
          .doesNotExist("hides editor after comment has been edited");
      });

      test("deleting a comment", async function (assert) {
        updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

        await visit("/t/280");

        assert
          .dom("#post_1 .post-voting-comment")
          .exists(
            { count: 1 },
            "displays the right number of comments for the first post"
          );

        await click("#post_1 .post-voting-comment-actions-delete-link");
        await click("button.btn-danger");

        assert
          .dom("#post_1 #post-voting-comment-1")
          .hasClass(
            "post-voting-comment-deleted",
            "adds the right class to deleted comment"
          );
      });

      test("deleting a comment after more comments have been loaded", async function (assert) {
        updateCurrentUser({ admin: true });

        await visit("/t/280");

        assert
          .dom("#post_2 .post-voting-comment")
          .exists(
            { count: 5 },
            "displays the right number of comments for the second post"
          );

        await click("#post_2 .post-voting-comments-menu-show-more-link");

        assert
          .dom("#post_2 .post-voting-comment")
          .exists({ count: 6 }, "appends the loaded comments");

        const comments = document.querySelectorAll(
          "#post_2 .post-voting-comment-actions-delete-link"
        );

        await click(comments[comments.length - 1]);
        await click("button.btn-danger");

        assert
          .dom("#post_2 .post-voting-comments-menu-show-more-link")
          .doesNotExist(
            "updates the comment count such that show more link is not displayed"
          );

        assert
          .dom("#post_2 #post-voting-comment-7")
          .hasClass(
            "post-voting-comment-deleted",
            "adds the right class to deleted comment"
          );
      });

      test("vote count display", async function (assert) {
        await visit("/t/280");

        assert
          .dom(
            "#post_2 #post-voting-comment-2 .post-voting-comment-actions-vote-count"
          )
          .doesNotExist("does not display element if vote count is zero");

        assert
          .dom(
            "#post_2 #post-voting-comment-3 .post-voting-comment-actions-vote-count"
          )
          .hasText("3", "displays the right vote count");
      });

      test("voting on a comment and removing vote", async function (assert) {
        await visit("/t/280");

        await click(
          "#post_2 #post-voting-comment-2 .post-voting-button-upvote"
        );

        assert
          .dom(
            "#post_2 #post-voting-comment-2 .post-voting-comment-actions-vote-count"
          )
          .hasText("1", "updates the comment vote count correctly");

        await click(
          "#post_2 #post-voting-comment-2 .post-voting-button-upvote"
        );

        assert
          .dom(
            "#post_2 #post-voting-comment-2 .post-voting-comment-actions-vote-count"
          )
          .doesNotExist("updates the comment vote count correctly");
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
          .dom("#post_2 span.post-voting-post-toggle-voters")
          .hasText("0", "displays the right count");

        assert
          .dom("#post_2 .post-voting-button-upvote")
          .doesNotHaveClass(
            "post-voting-button-voted",
            "does not highlight the upvote button"
          );
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
          .dom("#post_2 span.post-voting-post-toggle-voters")
          .hasText("0", "does not render a button to show post voters");
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
          .dom("#post_2 .post-voting-post-toggle-voters")
          .hasText("5", "displays the right post vote count");

        assert
          .dom("#post_2 .post-voting-button-upvote")
          .hasClass(
            "post-voting-button-voted",
            "highlights the upvote button for the current user"
          );

        assert
          .dom("#post_2 .post-voting-button-downvote")
          .doesNotHaveClass(
            "post-voting-button-voted",
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
          .dom("#post_2 .post-voting-post-toggle-voters")
          .hasText("5", "displays the right post vote count");

        assert
          .dom("#post_2 .post-voting-button-upvote")
          .hasClass(
            "post-voting-button-voted",
            "highlights the upvote button for the current user"
          );
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
          .includesText(
            "Test comment ABC",
            "appends comment to comments stream"
          );
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
          .dom("#post_2 .post-voting-comments-menu-show-more-link")
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
          .dom("#post_2 .post-voting-comments-menu-show-more-link")
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
          .hasClass(
            "post-voting-comment-deleted",
            "adds the right class to the comment"
          );
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
          .dom("#post_1 #post-voting-comment-1 .post-voting-comment-cooked")
          .hasText(
            "this is a new comment cooked",
            "updates the content of the comment"
          );

        await click(
          "#post_1 #post-voting-comment-1 .post-voting-comment-actions-edit-link"
        );

        assert
          .dom(
            "#post_1 #post-voting-comment-1 .post-voting-comment-composer textarea"
          )
          .hasValue(
            "this is a new comment raw",
            "updates the content of the comment editor"
          );
      });
    }
  );
});
