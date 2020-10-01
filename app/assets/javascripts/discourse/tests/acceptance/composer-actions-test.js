import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import { toggleCheckDraftPopup } from "discourse/controllers/composer";
import Draft from "discourse/models/draft";
import { Promise } from "rsvp";

acceptance("Composer Actions", {
  loggedIn: true,
  settings: {
    enable_whispers: true,
  },
  site: {
    can_tag_topics: true,
  },
});

QUnit.test(
  "creating new topic and then reply_as_private_message keeps attributes",
  async (assert) => {
    await visit("/");
    await click("button#create-topic");

    await fillIn("#reply-title", "this is the title");
    await fillIn(".d-editor-input", "this is the reply");

    const composerActions = selectKit(".composer-actions");
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_private_message");

    assert.ok(find("#reply-title").val(), "this is the title");
    assert.ok(find(".d-editor-input").val(), "this is the reply");
  }
);

QUnit.test("replying to post", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rowByIndex(5).value(), undefined);
});

QUnit.test("replying to post - reply_as_private_message", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_private_message");

  assert.equal(find(".users-input .item:eq(0)").text(), "codinghorror");
  assert.ok(
    find(".d-editor-input").val().indexOf("Continuing the discussion") >= 0
  );
});

QUnit.test("replying to post - reply_to_topic", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(
    ".d-editor-input",
    "test replying to topic when initially replied to post"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_to_topic");

  assert.equal(
    find(".action-title .topic-link").text().trim(),
    "Internationalization / localization"
  );
  assert.equal(
    find(".action-title .topic-link").attr("href"),
    "/t/internationalization-localization/280"
  );
  assert.equal(
    find(".d-editor-input").val(),
    "test replying to topic when initially replied to post"
  );
});

QUnit.test("replying to post - toggle_whisper", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(
    ".d-editor-input",
    "test replying as whisper to topic when initially not a whisper"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_whisper");

  assert.ok(
    find(".composer-fields .whisper .d-icon-far-eye-slash").length === 1
  );
});

QUnit.test("replying to post - reply_as_new_topic", async (assert) => {
  sandbox
    .stub(Draft, "get")
    .returns(Promise.resolve({ draft: "", draft_sequence: 0 }));
  const composerActions = selectKit(".composer-actions");
  const categoryChooser = selectKit(".title-wrapper .category-chooser");
  const categoryChooserReplyArea = selectKit(".reply-area .category-chooser");
  const quote = "test replying as new topic when initially replied to post";

  await visit("/t/internationalization-localization/280");

  await click("#topic-title .d-icon-pencil-alt");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(4);
  await click("#topic-title .submit-edit");

  await click("article#post_3 button.reply");
  await fillIn(".d-editor-input", quote);

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_new_topic");

  assert.equal(categoryChooserReplyArea.header().name(), "faq");
  assert.equal(
    find(".action-title").text().trim(),
    I18n.t("topic.create_long")
  );
  assert.ok(find(".d-editor-input").val().includes(quote));
  sandbox.restore();
});

QUnit.test("reply_as_new_topic without a new_topic draft", async (assert) => {
  await visit("/t/internationalization-localization/280");
  await click(".create.reply");
  const composerActions = selectKit(".composer-actions");
  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_new_topic");
  assert.equal(exists(find(".bootbox")), false);
});

QUnit.test("reply_as_new_group_message", async (assert) => {
  // eslint-disable-next-line
  server.get("/t/130.json", () => {
    return [
      200,
      { "Content-Type": "application/json" },
      {
        post_stream: {
          posts: [
            {
              id: 133,
              name: null,
              username: "bianca",
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              created_at: "2020-07-05T09:28:36.371Z",
              cooked:
                "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas a varius ipsum. Nunc euismod, metus non vulputate malesuada, ligula metus pharetra tortor, vel sodales arcu lacus sed mauris. Nam semper, orci vitae fringilla placerat, dui tellus convallis felis, ultricies laoreet sapien mi et metus. Mauris facilisis, mi fermentum rhoncus feugiat, dolor est vehicula leo, id porta leo ex non enim. In a ligula vel tellus commodo scelerisque non in ex. Pellentesque semper leo quam, nec varius est viverra eget. Donec vehicula sem et massa faucibus tempus.</p>",
              post_number: 1,
              post_type: 1,
              updated_at: "2020-07-05T09:28:36.371Z",
              reply_count: 0,
              reply_to_post_number: null,
              quote_count: 0,
              incoming_link_count: 0,
              reads: 1,
              readers_count: 0,
              score: 0,
              yours: true,
              topic_id: 130,
              topic_slug: "lorem-ipsum-dolor-sit-amet",
              display_username: null,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_bg_color: null,
              primary_group_flair_color: null,
              version: 1,
              can_edit: true,
              can_delete: false,
              can_recover: false,
              can_wiki: true,
              read: true,
              user_title: "Tester",
              title_is_group: false,
              actions_summary: [
                {
                  id: 3,
                  can_act: true,
                },
                {
                  id: 4,
                  can_act: true,
                },
                {
                  id: 8,
                  can_act: true,
                },
                {
                  id: 7,
                  can_act: true,
                },
              ],
              moderator: false,
              admin: true,
              staff: true,
              user_id: 1,
              hidden: false,
              trust_level: 0,
              deleted_at: null,
              user_deleted: false,
              edit_reason: null,
              can_view_edit_history: true,
              wiki: false,
              reviewable_id: 0,
              reviewable_score_count: 0,
              reviewable_score_pending_count: 0,
            },
          ],
          stream: [133],
        },
        timeline_lookup: [[1, 0]],
        related_messages: [],
        suggested_topics: [],
        id: 130,
        title: "Lorem ipsum dolor sit amet",
        fancy_title: "Lorem ipsum dolor sit amet",
        posts_count: 1,
        created_at: "2020-07-05T09:28:36.260Z",
        views: 1,
        reply_count: 0,
        like_count: 0,
        last_posted_at: "2020-07-05T09:28:36.371Z",
        visible: true,
        closed: false,
        archived: false,
        has_summary: false,
        archetype: "private_message",
        slug: "lorem-ipsum-dolor-sit-amet",
        category_id: null,
        word_count: 86,
        deleted_at: null,
        user_id: 1,
        featured_link: null,
        pinned_globally: false,
        pinned_at: null,
        pinned_until: null,
        image_url: null,
        draft: null,
        draft_key: "topic_130",
        draft_sequence: 0,
        posted: true,
        unpinned: null,
        pinned: false,
        current_post_number: 1,
        highest_post_number: 1,
        last_read_post_number: 1,
        last_read_post_id: 133,
        deleted_by: null,
        has_deleted: false,
        actions_summary: [
          {
            id: 4,
            count: 0,
            hidden: false,
            can_act: true,
          },
          {
            id: 8,
            count: 0,
            hidden: false,
            can_act: true,
          },
          {
            id: 7,
            count: 0,
            hidden: false,
            can_act: true,
          },
        ],
        chunk_size: 20,
        bookmarked: false,
        message_archived: false,
        topic_timer: null,
        message_bus_last_id: 5,
        participant_count: 1,
        pm_with_non_human_user: false,
        show_read_indicator: false,
        requested_group_name: null,
        thumbnails: null,
        tags_disable_ads: false,
        details: {
          notification_level: 3,
          notifications_reason_id: 1,
          can_move_posts: true,
          can_edit: true,
          can_delete: true,
          can_remove_allowed_users: true,
          can_invite_to: true,
          can_invite_via_email: true,
          can_create_post: true,
          can_reply_as_new_topic: true,
          can_flag_topic: true,
          can_convert_topic: true,
          can_review_topic: true,
          can_remove_self_id: 1,
          participants: [
            {
              id: 1,
              username: "bianca",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
              post_count: 1,
              primary_group_name: null,
              primary_group_flair_url: null,
              primary_group_flair_color: null,
              primary_group_flair_bg_color: null,
            },
          ],
          allowed_users: [
            {
              id: 7,
              username: "foo",
              name: null,
              avatar_template:
                "/letter_avatar_proxy/v4/letter/f/b19c9b/{size}.png",
            },
          ],
          created_by: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
          last_poster: {
            id: 1,
            username: "bianca",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
          },
          allowed_groups: [
            {
              id: 43,
              automatic: false,
              name: "foo_group",
              user_count: 4,
              mentionable_level: 0,
              messageable_level: 99,
              visibility_level: 0,
              automatic_membership_email_domains: "",
              primary_group: false,
              title: null,
              grant_trust_level: null,
              incoming_email: null,
              has_messages: true,
              flair_url: null,
              flair_bg_color: "",
              flair_color: "",
              bio_raw: null,
              bio_cooked: null,
              bio_excerpt: null,
              public_admission: false,
              public_exit: false,
              allow_membership_requests: false,
              full_name: null,
              default_notification_level: 3,
              membership_request_template: null,
              members_visibility_level: 0,
              can_see_members: true,
              publish_read_state: false,
            },
          ],
        },
      },
    ];
  });

  await visit("/t/lorem-ipsum-dolor-sit-amet/130");
  await click(".create.reply");
  const composerActions = selectKit(".composer-actions");
  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_new_group_message");

  const items = [];
  find(".users-input .item").each((_, item) =>
    items.push(item.textContent.trim())
  );

  assert.deepEqual(items, ["foo", "foo_group"]);
});

QUnit.test("hide component if no content", async (assert) => {
  await visit("/");
  await click("button#create-topic");

  const composerActions = selectKit(".composer-actions");
  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_private_message");

  assert.ok(composerActions.el().hasClass("is-hidden"));
  assert.equal(composerActions.el().children().length, 0);

  await click("button#create-topic");
  await composerActions.expand();
  assert.equal(composerActions.rows().length, 2);
});

QUnit.test("interactions", async (assert) => {
  const composerActions = selectKit(".composer-actions");
  const quote = "Life is like riding a bicycle.";

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(".d-editor-input", quote);
  await composerActions.expand();
  await composerActions.selectRowByValue("reply_to_topic");

  assert.equal(
    find(".action-title").text().trim(),
    "Internationalization / localization"
  );
  assert.equal(find(".d-editor-input").val(), quote);

  await composerActions.expand();

  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(composerActions.rowByIndex(1).value(), "reply_to_post");
  assert.equal(
    composerActions.rowByIndex(2).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rows().length, 5);

  await composerActions.selectRowByValue("reply_to_post");
  await composerActions.expand();

  assert.ok(exists(find(".action-title img.avatar")));
  assert.equal(find(".action-title .user-link").text().trim(), "codinghorror");
  assert.equal(find(".d-editor-input").val(), quote);
  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rows().length, 5);

  await composerActions.selectRowByValue("reply_as_new_topic");
  await composerActions.expand();

  assert.equal(
    find(".action-title").text().trim(),
    I18n.t("topic.create_long")
  );
  assert.ok(find(".d-editor-input").val().includes(quote));
  assert.equal(composerActions.rowByIndex(0).value(), "reply_to_post");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "shared_draft");
  assert.equal(composerActions.rows().length, 4);

  await composerActions.selectRowByValue("reply_as_private_message");
  await composerActions.expand();

  assert.equal(
    find(".action-title").text().trim(),
    I18n.t("topic.private_message")
  );
  assert.ok(
    find(".d-editor-input").val().indexOf("Continuing the discussion") === 0
  );
  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(composerActions.rowByIndex(1).value(), "reply_to_post");
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rows().length, 3);
});

QUnit.test("replying to post - toggle_topic_bump", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");

  assert.ok(
    find(".composer-fields .no-bump").length === 0,
    "no-bump text is not visible"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_topic_bump");

  assert.ok(
    find(".composer-fields .no-bump").length === 1,
    "no-bump icon is visible"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_topic_bump");

  assert.ok(
    find(".composer-fields .no-bump").length === 0,
    "no-bump icon is not visible"
  );
});

QUnit.test("replying to post as staff", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  updateCurrentUser({ admin: true });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 5);
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
});

QUnit.test("replying to post as TL3 user", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  updateCurrentUser({ moderator: false, admin: false, trust_level: 3 });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 3);
  Array.from(composerActions.rows()).forEach((row) => {
    assert.notEqual(
      row.value,
      "toggle_topic_bump",
      "toggle button is not visible"
    );
  });
});

QUnit.test("replying to post as TL4 user", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 4);
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_topic_bump");
});

QUnit.test(
  "replying to first post - reply_as_private_message",
  async (assert) => {
    const composerActions = selectKit(".composer-actions");

    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.reply");

    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_private_message");

    assert.equal(find(".users-input .item:eq(0)").text(), "uwe_keim");
    assert.ok(
      find(".d-editor-input").val().indexOf("Continuing the discussion") >= 0
    );
  }
);

QUnit.test("editing post", async (assert) => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_1 button.show-more-actions");
  await click("article#post_1 button.edit");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 1);
  assert.equal(composerActions.rowByIndex(0).value(), "reply_to_post");
});

acceptance("Composer Actions With New Topic Draft", {
  loggedIn: true,
  settings: {
    enable_whispers: true,
  },
  site: {
    can_tag_topics: true,
  },
  beforeEach() {
    _clearSnapshots();
  },
  afterEach() {
    _clearSnapshots();
  },
});

const stubDraftResponse = () => {
  sandbox.stub(Draft, "get").returns(
    Promise.resolve({
      draft:
        '{"reply":"dum de dum da ba.","action":"createTopic","title":"dum da ba dum dum","categoryId":null,"archetypeId":"regular","metaData":null,"composerTime":540879,"typingTime":3400}',
      draft_sequence: 0,
    })
  );
};

QUnit.test("shared draft", async (assert) => {
  stubDraftResponse();
  try {
    toggleCheckDraftPopup(true);

    const composerActions = selectKit(".composer-actions");
    const tags = selectKit(".mini-tag-chooser");

    await visit("/");
    await click("#create-topic");

    await fillIn(
      "#reply-title",
      "This is the new text for the title using 'quotes'"
    );

    await fillIn(".d-editor-input", "This is the new text for the post");
    await tags.expand();
    await tags.selectRowByValue("monkey");
    await composerActions.expand();
    await composerActions.selectRowByValue("shared_draft");

    assert.equal(tags.header().value(), "monkey", "tags are not reset");

    assert.equal(
      find("#reply-title").val(),
      "This is the new text for the title using 'quotes'"
    );

    assert.equal(
      find("#reply-control .btn-primary.create .d-button-label").text(),
      I18n.t("composer.create_shared_draft")
    );

    assert.ok(find("#reply-control.composing-shared-draft").length === 1);
    await click(".modal-footer .btn.btn-default");
  } finally {
    toggleCheckDraftPopup(false);
  }
  sandbox.restore();
});

QUnit.test("reply_as_new_topic with new_topic draft", async (assert) => {
  await visit("/t/internationalization-localization/280");
  await click(".create.reply");
  const composerActions = selectKit(".composer-actions");
  await composerActions.expand();
  stubDraftResponse();
  await composerActions.selectRowByValue("reply_as_new_topic");
  assert.equal(
    find(".bootbox .modal-body").text(),
    I18n.t("composer.composer_actions.reply_as_new_topic.confirm")
  );
  await click(".modal-footer .btn.btn-default");
  sandbox.restore();
});
