import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function setupGroupPretender(server, helper) {
  server.post("/groups/Macdonald/request_membership.json", () => {
    return helper.response({
      relative_url: "/t/internationalization-localization/280",
    });
  });
}

function setupGroupTest(needs) {
  needs.settings({ enable_group_directory: true });
}

acceptance("Group - Anonymous", function (needs) {
  setupGroupTest(needs);
  needs.pretender(setupGroupPretender);

  test("Anonymous Viewing Group", async function (assert) {
    await visit("/g/discourse");

    assert
      .dom(".nav-pills li a[title='Messages']")
      .doesNotExist("does not show group messages navigation link");

    await click(".nav-pills li a[title='Activity']");

    assert.dom(".post-list-item").exists("lists stream items");

    await click(".activity-nav li a[href='/g/discourse/activity/topics']");

    assert.dom(".topic-list").exists("shows the topic list");
    assert.dom(".topic-list-item").exists({ count: 2 }, "lists stream items");

    await click(".activity-nav li a[href='/g/discourse/activity/mentions']");

    assert.dom(".post-list-item").exists("lists stream items");
    assert
      .dom(".nav-pills li a[title='Edit Group']")
      .doesNotExist("does not show messages tab if user is not admin");
    assert
      .dom(".nav-pills li a[title='Logs']")
      .doesNotExist("does not show Logs tab if user is not admin");
    assert.dom(".post-list-item").exists("lists stream items");

    const groupDropdown = selectKit(".group-dropdown");
    await groupDropdown.expand();

    assert.strictEqual(groupDropdown.rowByIndex(1).name(), "discourse");

    assert.strictEqual(
      groupDropdown.rowByIndex(0).name(),
      i18n("groups.index.all")
    );

    this.siteSettings.enable_group_directory = false;

    await visit("/g");
    await visit("/g/discourse");

    await groupDropdown.expand();

    assert
      .dom(".group-dropdown-filter")
      .doesNotExist("does not display the default header");
  });

  test("Anonymous Viewing Automatic Group", async function (assert) {
    await visit("/g/moderators");

    assert
      .dom(".nav-pills li a[title='Manage']")
      .doesNotExist("does not show group messages navigation link");
  });
});

acceptance("Group - Authenticated", function (needs) {
  setupGroupTest(needs);
  needs.user();

  needs.pretender((server, helper) => {
    setupGroupPretender(server, helper);
    server.get(
      "/topics/private-messages-group/eviltrout/alternative-group.json",
      () => {
        return helper.response({ topic_list: { topics: [] } });
      }
    );

    server.get(
      "/topics/private-messages-group/eviltrout/discourse.json",
      () => {
        return helper.response({
          users: [
            {
              id: 2,
              username: "bruce1",
              avatar_template:
                "/user_avatar/meta.discourse.org/bruce1/{size}/5245.png",
            },
            {
              id: 3,
              username: "CodingHorror",
              avatar_template:
                "/user_avatar/meta.discourse.org/codinghorror/{size}/5245.png",
            },
          ],
          primary_groups: [],
          topic_list: {
            can_create_topic: true,
            draft: null,
            draft_key: "new_topic",
            draft_sequence: 0,
            per_page: 30,
            topics: [
              {
                id: 12199,
                title: "This is a private message 1",
                fancy_title: "This is a private message 1",
                slug: "this-is-a-private-message-1",
                posts_count: 0,
                reply_count: 0,
                highest_post_number: 0,
                image_url: null,
                created_at: "2018-03-16T03:38:45.583Z",
                last_posted_at: null,
                bumped: true,
                bumped_at: "2018-03-16T03:38:45.583Z",
                unseen: false,
                pinned: false,
                unpinned: null,
                visible: true,
                closed: false,
                archived: false,
                bookmarked: null,
                liked: null,
                views: 0,
                like_count: 0,
                has_summary: false,
                archetype: "private_message",
                last_poster_username: "bruce1",
                category_id: null,
                pinned_globally: false,
                featured_link: null,
                posters: [
                  {
                    extras: "latest single",
                    description: "Original Poster, Most Recent Poster",
                    user_id: 2,
                    primary_group_id: null,
                  },
                ],
                participants: [
                  {
                    extras: "latest",
                    description: null,
                    user_id: 2,
                    primary_group_id: null,
                  },
                  {
                    extras: null,
                    description: null,
                    user_id: 3,
                    primary_group_id: null,
                  },
                ],
              },
            ],
          },
        });
      }
    );
  });

  test("User Viewing Group", async function (assert) {
    await visit("/g");
    await click(".group-index-request");

    assert
      .dom(".d-modal__header .d-modal__title-text")
      .hasText(
        i18n("groups.membership_request.title", { group_name: "Macdonald" })
      );

    assert
      .dom(".request-group-membership-form textarea")
      .hasValue("Please add me");

    await click(".d-modal__footer .btn-primary");

    assert.dom(".fancy-title").hasText("Internationalization / localization");

    await visit("/g/discourse");

    await click(".group-message-button");

    assert.dom("#reply-control").exists("opens the composer");
    const privateMessageUsers = selectKit("#private-message-users");
    assert.strictEqual(
      privateMessageUsers.header().value(),
      "discourse",
      "prefills the group name"
    );

    assert.dom(".add-warning").doesNotExist("groups can't receive warnings");
  });

  test("Admin viewing group messages when there are no messages", async function (assert) {
    await visit("/g/alternative-group");
    await click(".nav-pills li a[title='Messages']");

    assert
      .dom("span.empty-state-title")
      .hasText(
        i18n("no_group_messages_title"),
        "should display the right text"
      );
  });

  test("Admin viewing group messages", async function (assert) {
    await visit("/g/discourse");
    await click(".nav-pills li a[title='Messages']");

    assert
      .dom(".topic-list-item .link-top-line")
      .hasText(
        "This is a private message 1",
        "should display the list of group topics"
      );

    await click("#search-button");
    await fillIn("#search-term", "something");

    assert
      .dom(".search-menu .btn.search-context")
      .exists("'in messages' toggle is active by default");
  });

  test("Admin Viewing Group", async function (assert) {
    await visit("/g/discourse");

    assert
      .dom(".nav-pills li a[title='Manage']")
      .exists("shows manage group tab if user is admin");

    assert
      .dom(".group-message-button")
      .exists("displays show group message button");
    assert
      .dom(".group-info-name")
      .hasText("Awesome Team", "should display the group name");

    await click(".group-details-button button.btn-danger");

    assert.dom(".dialog-body p:nth-of-type(2)").hasText(
      i18n("admin.groups.delete_with_messages_confirm", {
        count: 2,
      }),
      "warns about orphan messages"
    );

    await click(".dialog-footer .btn-default");

    await visit("/g/discourse/activity/posts");

    assert
      .dom(".post-list-item a.avatar-link")
      .hasAttribute(
        "href",
        "/u/awesomerobot",
        "avatar link contains href (is tabbable)"
      );
  });

  test("Moderator Viewing Group", async function (assert) {
    await visit("/g/alternative-group");

    assert
      .dom(".nav-pills li a[title='Manage']")
      .exists("shows manage group tab if user can_admin_group");

    await click(".group-members-add.btn");

    assert
      .dom(".group-add-members-modal #set-owner")
      .exists("allows moderators to set group owners");

    await click(".group-add-members-modal .modal-close");

    const memberDropdown = selectKit(".group-member-dropdown:nth-of-type(1)");
    await memberDropdown.expand();

    assert.strictEqual(
      memberDropdown.rowByIndex(0).name(),
      i18n("groups.members.remove_member")
    );
    assert.strictEqual(
      memberDropdown.rowByIndex(1).name(),
      i18n("groups.members.make_owner")
    );
  });
});
