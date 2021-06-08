import {
  acceptance,
  count,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Managing Group Membership", function (needs) {
  needs.user();

  test("As an admin", async function (assert) {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert.equal(
      count('label[for="automatic_membership"]'),
      1,
      "it should display automatic membership label"
    );

    assert.equal(
      count(".groups-form-primary-group"),
      1,
      "it should display set as primary group checkbox"
    );

    assert.equal(
      count(".groups-form-grant-trust-level"),
      1,
      "it should display grant trust level selector"
    );

    assert.equal(
      count(".group-form-public-admission"),
      1,
      "it should display group public admission input"
    );

    assert.equal(
      count(".group-form-public-exit"),
      1,
      "it should display group public exit input"
    );

    assert.equal(
      count(".group-form-allow-membership-requests"),
      1,
      "it should display group allow_membership_request input"
    );

    assert.equal(
      count(".group-form-allow-membership-requests[disabled]"),
      1,
      "it should disable group allow_membership_request input"
    );

    assert.equal(
      count(".group-flair-inputs"),
      1,
      "it should display avatar flair inputs"
    );

    await click(".group-form-public-admission");
    await click(".group-form-allow-membership-requests");

    assert.equal(
      count(".group-form-public-admission[disabled]"),
      1,
      "it should disable group public admission input"
    );

    assert.ok(
      !exists(".group-form-public-exit[disabled]"),
      "it should not disable group public exit input"
    );

    assert.equal(
      count(".group-form-membership-request-template"),
      1,
      "it should display the membership request template field"
    );

    const emailDomains = selectKit(
      ".group-form-automatic-membership-automatic"
    );
    await emailDomains.expand();
    await emailDomains.fillInFilter("foo.com");
    await emailDomains.keyboard("enter");

    assert.equal(emailDomains.header().value(), "foo.com");
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/membership");

    assert.ok(
      !exists('label[for="automatic_membership"]'),
      "it should not display automatic membership label"
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

    assert.equal(
      count(".group-form-public-admission"),
      1,
      "it should display group public admission input"
    );

    assert.equal(
      count(".group-form-public-exit"),
      1,
      "it should display group public exit input"
    );

    assert.equal(
      count(".group-form-allow-membership-requests"),
      1,
      "it should display group allow_membership_request input"
    );

    assert.equal(
      count(".group-form-allow-membership-requests[disabled]"),
      1,
      "it should disable group allow_membership_request input"
    );
  });
});
