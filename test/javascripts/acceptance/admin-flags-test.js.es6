import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Flagging", { loggedIn: true });

QUnit.test("flagged posts", assert => {
  visit("/admin/flags/active");
  andThen(() => {
    assert.equal(find(".flagged-posts .flagged-post").length, 1);
    assert.equal(
      find(".flagged-post .flag-user").length,
      1,
      "shows who flagged it"
    );
    assert.equal(find(".flagged-post-response").length, 2);
    assert.equal(find(".flagged-post-response:eq(0) img.avatar").length, 1);
    assert.equal(
      find(".flagged-post-user-details .username").length,
      1,
      "shows the flagged username"
    );
  });
});

QUnit.test("flagged posts - agree", assert => {
  const agreeFlag = selectKit(".agree-flag");

  visit("/admin/flags/active");

  agreeFlag.expand().selectRowByValue("confirm-agree-keep");

  andThen(() => {
    assert.equal(
      find(".admin-flags .flagged-post").length,
      0,
      "post was removed"
    );
  });
});

QUnit.test("flagged posts - agree + hide", assert => {
  const agreeFlag = selectKit(".agree-flag");

  visit("/admin/flags/active");

  agreeFlag.expand().selectRowByValue("confirm-agree-hide");

  andThen(() => {
    assert.equal(
      find(".admin-flags .flagged-post").length,
      0,
      "post was removed"
    );
  });
});

QUnit.test("flagged posts - agree + deleteSpammer", assert => {
  const agreeFlag = selectKit(".agree-flag");

  visit("/admin/flags/active");

  agreeFlag.expand().selectRowByValue("delete-spammer");

  click(".confirm-delete");

  andThen(() => {
    assert.equal(
      find(".admin-flags .flagged-post").length,
      0,
      "post was removed"
    );
  });
});

QUnit.test("flagged posts - disagree", assert => {
  visit("/admin/flags/active");
  click(".disagree-flag");
  andThen(() => {
    assert.equal(find(".admin-flags .flagged-post").length, 0);
  });
});

QUnit.test("flagged posts - defer", assert => {
  visit("/admin/flags/active");
  click(".defer-flag");
  andThen(() => {
    assert.equal(find(".admin-flags .flagged-post").length, 0);
  });
});

QUnit.test("flagged posts - delete + defer", assert => {
  const deleteFlag = selectKit(".delete-flag");

  visit("/admin/flags/active");

  deleteFlag.expand().selectRowByValue("delete-defer");

  andThen(() => {
    assert.equal(find(".admin-flags .flagged-post").length, 0);
  });
});

QUnit.test("flagged posts - delete + agree", assert => {
  const deleteFlag = selectKit(".delete-flag");

  visit("/admin/flags/active");

  deleteFlag.expand().selectRowByValue("delete-agree");

  andThen(() => {
    assert.equal(find(".admin-flags .flagged-post").length, 0);
  });
});

QUnit.test("flagged posts - delete + deleteSpammer", assert => {
  const deleteFlag = selectKit(".delete-flag");

  visit("/admin/flags/active");

  deleteFlag.expand().selectRowByValue("delete-spammer");

  click(".confirm-delete");

  andThen(() => {
    assert.equal(find(".admin-flags .flagged-post").length, 0);
  });
});

QUnit.test("topics with flags", assert => {
  visit("/admin/flags/topics");
  andThen(() => {
    assert.equal(find(".flagged-topics .flagged-topic").length, 1);
    assert.equal(find(".flagged-topic .flagged-topic-user").length, 2);
    assert.equal(find(".flagged-topic div.flag-counts").length, 3);
  });

  click(".flagged-topic .show-details");
  andThen(() => {
    assert.equal(currentURL(), "/admin/flags/topics/280");
  });
});
