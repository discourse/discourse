import {
  acceptance,
  count,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import Site from "discourse/models/site";

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

    assert.strictEqual(
      count('label[for="automatic_membership"]'),
      1,
      "it should display automatic membership label"
    );

    assert.strictEqual(
      count(".groups-form-primary-group"),
      1,
      "it should display set as primary group checkbox"
    );

    assert.strictEqual(
      count(".groups-form-grant-trust-level"),
      1,
      "it should display grant trust level selector"
    );

    assert.strictEqual(
      count(".group-form-public-admission"),
      1,
      "it should display group public admission input"
    );

    assert.strictEqual(
      count(".group-form-public-exit"),
      1,
      "it should display group public exit input"
    );

    assert.strictEqual(
      count(".group-form-allow-membership-requests"),
      1,
      "it should display group allow_membership_request input"
    );

    assert.strictEqual(
      count(".group-form-allow-membership-requests[disabled]"),
      1,
      "it should disable group allow_membership_request input"
    );

    assert.strictEqual(
      count(".group-flair-inputs"),
      1,
      "it should display avatar flair inputs"
    );

    await click(".group-form-public-admission");
    await click(".group-form-allow-membership-requests");

    assert.strictEqual(
      count(".group-form-public-admission[disabled]"),
      1,
      "it should disable group public admission input"
    );

    assert.ok(
      !exists(".group-form-public-exit[disabled]"),
      "it should not disable group public exit input"
    );

    assert.strictEqual(
      count(".group-form-membership-request-template"),
      1,
      "it should display the membership request template field"
    );

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

    assert.equal(associatedGroups.header().name(), "google_oauth2:test-group");
  });

  test("As an admin on a site that can't associate groups", async function (assert) {
    let site = Site.current();
    site.set("can_associate_groups", false);
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert.ok(
      !exists('label[for="automatic_membership_associated_groups"]'),
      "it should not display associated groups automatic membership label"
    );
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/membership");

    assert.ok(
      !exists('label[for="automatic_membership"]'),
      "it should not display automatic membership label"
    );

    assert.ok(
      !exists('label[for="automatic_membership_associated_groups"]'),
      "it should not display associated groups automatic membership label"
    );

    assert.ok(
      !exists(".groups-form-automatic-membership-retroactive"),
      "it should not display automatic membership retroactive checkbox"
    );

    assert.ok(
      !exists(".groups-form-primary-group"),
      "it should not display set as primary group checkbox"
    );

    assert.ok(
      !exists(".groups-form-grant-trust-level"),
      "it should not display grant trust level selector"
    );

    assert.strictEqual(
      count(".group-form-public-admission"),
      1,
      "it should display group public admission input"
    );

    assert.strictEqual(
      count(".group-form-public-exit"),
      1,
      "it should display group public exit input"
    );

    assert.strictEqual(
      count(".group-form-allow-membership-requests"),
      1,
      "it should display group allow_membership_request input"
    );

    assert.strictEqual(
      count(".group-form-allow-membership-requests[disabled]"),
      1,
      "it should disable group allow_membership_request input"
    );
  });
});
