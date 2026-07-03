import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import groupFixtures from "discourse/tests/fixtures/group-fixtures";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Managing Group Membership", function (needs) {
  let savedGroup;

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/associated_groups", () =>
      helper.response({
        associated_groups: [
          {
            id: 123,
            name: "test-group",
            provider_name: "google_oauth2",
            label: "google_oauth2:test-group",
          },
        ],
      })
    );

    server.put("/groups/57", (request) => {
      savedGroup = helper.parsePostData(request.requestBody).group;
      return helper.response({ success: "OK" });
    });

    server.put("/admin/groups/automatic_membership_count.json", (request) => {
      const domains = (
        helper.parsePostData(request.requestBody)
          .automatic_membership_email_domains || ""
      ).split("|");
      const invalid_domains = domains.filter((domain) => domain.includes("@"));
      return helper.response({ user_count: 0, invalid_domains });
    });
  });

  needs.hooks.beforeEach(() => (savedGroup = null));

  test("As an admin", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert
      .dom(".groups-form-visibility-level")
      .exists("displays visibility level selector");

    assert
      .dom('label[for="automatic_membership"]')
      .exists("displays automatic membership label");

    assert
      .dom(".groups-form-primary-group")
      .exists("displays set as primary group checkbox");

    assert
      .dom(".groups-form-grant-trust-level")
      .exists("displays grant trust level selector");

    assert
      .dom(".group-form-public-admission")
      .exists("displays the join freely option");

    assert
      .dom(".group-form-public-admission")
      .isChecked("selects join freely for this group");

    assert
      .dom(".group-form-allow-membership-requests")
      .exists("displays the membership request option");

    assert
      .dom(".group-form-invite-only")
      .exists("displays the invite only option");

    assert
      .dom(".group-form-public-exit")
      .exists("displays group public exit input");

    assert.dom(".group-flair-inputs").exists("displays avatar flair inputs");

    await click(".group-form-allow-membership-requests");

    assert
      .dom(".group-form-allow-membership-requests")
      .isChecked("selects the membership request option");

    assert
      .dom(".group-form-membership-request-template")
      .exists(
        "displays the membership request template field when requests are enabled"
      );

    const emailDomains = selectKit(
      ".group-form-automatic-membership-automatic"
    );
    await emailDomains.expand();
    await emailDomains.fillInFilter("foo.com");
    await emailDomains.selectRowByValue("foo.com");

    assert.strictEqual(emailDomains.header().value(), "foo.com");
  });

  test("warns and blocks the save when a domain includes '@'", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    const emailDomains = selectKit(
      ".group-form-automatic-membership-automatic"
    );
    await emailDomains.expand();
    await emailDomains.fillInFilter("@harness.io");
    await emailDomains.selectRowByValue("@harness.io");

    await click(".group-manage-save");

    assert
      .dom(".dialog-body")
      .hasText(
        i18n(
          "admin.groups.manage.membership.automatic_membership_email_domains_invalid",
          { count: 1, domains: "@harness.io" }
        ),
        "shows the invalid-domain warning"
      );

    assert.strictEqual(savedGroup, null, "does not save the group");
  });

  test("the join method constrains the group's visibility options", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert
      .dom(".group-form-public-admission")
      .isChecked("join freely is selected for this group");

    const visibility = selectKit(".select-kit.groups-form-visibility-level");
    await visibility.expand();

    assert
      .dom(".groups-form-visibility-level .select-kit-row[data-value='2']")
      .doesNotExist("members-only visibility is removed while anyone can join");
    assert
      .dom(".groups-form-visibility-level .select-kit-row[data-value='0']")
      .exists("public visibility stays available");

    await visibility.collapse();

    await click(".group-form-invite-only");
    await visibility.expand();

    assert
      .dom(".groups-form-visibility-level .select-kit-row[data-value='2']")
      .exists("members-only visibility returns for invite-only groups");
  });

  test("choosing a join method that needs visibility reopens a restricted group", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    // make it invite-only first so a restricted visibility can be picked
    await click(".group-form-invite-only");

    const visibility = selectKit(".select-kit.groups-form-visibility-level");
    await visibility.expand();
    await visibility.selectRowByValue("2");

    assert.strictEqual(
      visibility.header().value(),
      "2",
      "members-only visibility is set while invite-only"
    );

    await click(".group-form-public-admission");

    assert.strictEqual(
      visibility.header().value(),
      "0",
      "switching to join freely resets visibility to public"
    );
  });

  test("each join method serializes to the matching booleans on save", async function (assert) {
    updateCurrentUser({ admin: true });

    await visit("/g/alternative-group/manage/membership");

    await click(".group-form-allow-membership-requests");
    await click(".group-manage-save");

    assert.strictEqual(
      savedGroup.public_admission,
      "false",
      "by request clears public_admission"
    );
    assert.strictEqual(
      savedGroup.allow_membership_requests,
      "true",
      "by request sets allow_membership_requests"
    );

    await click(".group-form-invite-only");
    await click(".group-manage-save");

    assert.strictEqual(
      savedGroup.public_admission,
      "false",
      "invite only clears public_admission"
    );
    assert.strictEqual(
      savedGroup.allow_membership_requests,
      "false",
      "invite only clears allow_membership_requests"
    );
  });

  test("As an admin on a site that can associate groups", async function (assert) {
    let site = Site.current();
    site.set("can_associate_groups", true);
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    const associatedGroups = selectKit(
      ".group-form-automatic-membership-associated-groups"
    );
    await associatedGroups.expand();
    await associatedGroups.selectRowByName("google_oauth2:test-group");
    await associatedGroups.keyboard("enter");

    assert.strictEqual(
      associatedGroups.header().name(),
      "google_oauth2:test-group"
    );
  });

  test("As an admin on a site that can't associate groups", async function (assert) {
    let site = Site.current();
    site.set("can_associate_groups", false);
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert
      .dom('label[for="automatic_membership_associated_groups"]')
      .doesNotExist(
        "it should not display associated groups automatic membership label"
      );
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/membership");

    assert
      .dom(".groups-form-visibility-level")
      .doesNotExist("does not display visibility level selector");

    assert
      .dom('label[for="automatic_membership"]')
      .doesNotExist("it should not display automatic membership label");

    assert
      .dom('label[for="automatic_membership_associated_groups"]')
      .doesNotExist(
        "it should not display associated groups automatic membership label"
      );

    assert
      .dom(".groups-form-automatic-membership-retroactive")
      .doesNotExist(
        "it should not display automatic membership retroactive checkbox"
      );

    assert
      .dom(".groups-form-primary-group")
      .doesNotExist("it should not display set as primary group checkbox");

    assert
      .dom(".groups-form-grant-trust-level")
      .doesNotExist("it should not display grant trust level selector");

    assert
      .dom(".group-form-public-admission")
      .exists("displays the join freely option");

    assert
      .dom(".group-form-allow-membership-requests")
      .exists("displays the membership request option");

    assert
      .dom(".group-form-invite-only")
      .exists("displays the invite only option");

    assert
      .dom(".group-form-public-exit")
      .exists("displays group public exit input");
  });
});

acceptance(
  "Managing Group Membership - too many automatic membership domains",
  function (needs) {
    let savedGroup;

    needs.user();
    needs.pretender((server, helper) => {
      server.put("/admin/groups/automatic_membership_count.json", () =>
        helper.response({ user_count: null, invalid_domains: [] })
      );

      server.put("/groups/57", (request) => {
        savedGroup = helper.parsePostData(request.requestBody).group;
        return helper.response({ success: "OK" });
      });
    });

    needs.hooks.beforeEach(() => (savedGroup = null));

    test("confirms with a generic message when there are too many domains to count", async function (assert) {
      updateCurrentUser({ can_create_group: true });

      await visit("/g/alternative-group/manage/membership");

      const emailDomains = selectKit(
        ".group-form-automatic-membership-automatic"
      );
      await emailDomains.expand();
      await emailDomains.fillInFilter("example.com");
      await emailDomains.selectRowByValue("example.com");

      await click(".group-manage-save");

      assert
        .dom(".dialog-body")
        .hasText(
          i18n(
            "admin.groups.manage.membership.automatic_membership_user_unknown_count"
          ),
          "shows the generic unknown-count confirmation"
        );

      await click(".dialog-footer .btn-primary");

      assert.notStrictEqual(
        savedGroup,
        null,
        "saves the group after confirming"
      );
    });
  }
);

acceptance(
  "Managing Group Membership - non-admin owner of a private group",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/groups/discourse.json", () => {
        const cloned = cloneJSON(groupFixtures["/groups/discourse.json"]);
        cloned.group.visibility_level = 2;
        cloned.group.public_admission = false;
        cloned.group.allow_membership_requests = false;
        cloned.group.can_admin_group = false;
        return helper.response(cloned);
      });
    });

    test("hides the open join methods that need a visible group", async function (assert) {
      updateCurrentUser({ admin: false, moderator: false });

      await visit("/g/discourse/manage/membership");

      assert
        .dom(".group-form-invite-only")
        .exists("invite only remains available");

      assert
        .dom(".group-form-public-admission")
        .doesNotExist("join freely is hidden when the group isn't visible");

      assert
        .dom(".group-form-allow-membership-requests")
        .doesNotExist("request to join is hidden when the group isn't visible");

      assert
        .dom(".groups-form-visibility-level")
        .doesNotExist("a non-admin owner can't change visibility to fix it");
    });
  }
);

acceptance(
  "Automatic Group Tooltip - can_admin_group is true",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/groups/moderators.json", () => {
        const cloned = cloneJSON(groupFixtures["/groups/moderators.json"]);
        cloned.group.can_admin_group = true;
        cloned.group.is_group_owner = false;
        return helper.response(200, cloned);
      });
    });

    test("the current user can see the tooltip because they can manage the group", async function (assert) {
      await visit("/g/moderators");

      assert
        .dom(".group-automatic-tooltip")
        .exists("displays automatic tooltip");
    });

    test("the current user cannot invite users to automatic group", async function (assert) {
      await visit("/g/moderators");
      assert.dom(".group-members-add").doesNotExist();
    });
  }
);

acceptance(
  "Automatic Group Tooltip - can_admin_group is false",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/groups/moderators.json", () => {
        const cloned = cloneJSON(groupFixtures["/groups/moderators.json"]);
        cloned.group.can_admin_group = false;
        cloned.group.is_group_owner = false;
        return helper.response(200, cloned);
      });
    });

    test("the current user cannot see the tooltip because they cannot manage the group", async function (assert) {
      await visit("/g/moderators");

      assert
        .dom(".group-automatic-tooltip")
        .doesNotExist("does not display automatic tooltip");
    });
  }
);
