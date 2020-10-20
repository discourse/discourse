import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Managing Group Membership", function (needs) {
  needs.user();

  test("As an admin", async (assert) => {
    updateCurrentUser({ can_create_group: true });

    await visit("/g/alternative-group/manage/membership");

    assert.ok(
      find('label[for="automatic_membership"]').length === 1,
      "it should display automatic membership label"
    );

    assert.ok(
      find(".groups-form-primary-group").length === 1,
      "it should display set as primary group checkbox"
    );

    assert.ok(
      find(".groups-form-grant-trust-level").length === 1,
      "it should display grant trust level selector"
    );

    assert.ok(
      find(".group-form-public-admission").length === 1,
      "it should display group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit").length === 1,
      "it should display group public exit input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests").length === 1,
      "it should display group allow_membership_request input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests[disabled]").length === 1,
      "it should disable group allow_membership_request input"
    );

    await click(".group-form-public-admission");
    await click(".group-form-allow-membership-requests");

    assert.ok(
      find(".group-form-public-admission[disabled]").length === 1,
      "it should disable group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit[disabled]").length === 0,
      "it should not disable group public exit input"
    );

    assert.equal(
      find(".group-form-membership-request-template").length,
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

  test("As a group owner", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/membership");

    assert.ok(
      find('label[for="automatic_membership"]').length === 0,
      "it should not display automatic membership label"
    );

    assert.ok(
      find(".groups-form-automatic-membership-retroactive").length === 0,
      "it should not display automatic membership retroactive checkbox"
    );

    assert.ok(
      find(".groups-form-primary-group").length === 0,
      "it should not display set as primary group checkbox"
    );

    assert.ok(
      find(".groups-form-grant-trust-level").length === 0,
      "it should not display grant trust level selector"
    );

    assert.ok(
      find(".group-form-public-admission").length === 1,
      "it should display group public admission input"
    );

    assert.ok(
      find(".group-form-public-exit").length === 1,
      "it should display group public exit input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests").length === 1,
      "it should display group allow_membership_request input"
    );

    assert.ok(
      find(".group-form-allow-membership-requests[disabled]").length === 1,
      "it should disable group allow_membership_request input"
    );
  });
});
