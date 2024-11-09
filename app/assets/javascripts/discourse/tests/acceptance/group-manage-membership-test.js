import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Managing Group Membership", function (needs) {
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
  });

  test("As an admin", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

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
      .exists("displays group public admission input");

    assert
      .dom(".group-form-public-exit")
      .exists("displays group public exit input");

    assert
      .dom(".group-form-allow-membership-requests")
      .exists("displays group allow_membership_request input");

    assert
      .dom(".group-form-allow-membership-requests")
      .isDisabled("disables group allow_membership_request input");

    assert.dom(".group-flair-inputs").exists("displays avatar flair inputs");

    await click(".group-form-public-admission");
    await click(".group-form-allow-membership-requests");

    assert
      .dom(".group-form-public-admission")
      .isDisabled("disables group public admission input");

    assert
      .dom(".group-form-public-exit")
      .isNotDisabled("it should not disable group public exit input");

    assert
      .dom(".group-form-membership-request-template")
      .exists("displays the membership request template field");

    const emailDomains = selectKit(
      ".group-form-automatic-membership-automatic"
    );
    await emailDomains.expand();
    await emailDomains.fillInFilter("foo.com");
    await emailDomains.selectRowByValue("foo.com");

    assert.strictEqual(emailDomains.header().value(), "foo.com");
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
      .exists("displays group public admission input");

    assert
      .dom(".group-form-public-exit")
      .exists("displays group public exit input");

    assert
      .dom(".group-form-allow-membership-requests")
      .exists("displays group allow_membership_request input");

    assert
      .dom(".group-form-allow-membership-requests")
      .isDisabled("disables group allow_membership_request input");
  });
});
