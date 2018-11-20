import { acceptance } from "helpers/qunit-helpers";
acceptance("Admin - Flagging", { loggedIn: true });

QUnit.test("flagged posts", async assert => {
  await visit("/admin/flags/active");

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

QUnit.test("flagged posts - agree", async assert => {
  const agreeFlag = selectKit(".agree-flag");

  await visit("/admin/flags/active");

  await agreeFlag.expand();
  await agreeFlag.selectRowByValue("confirm-agree-keep");

  assert.equal(
    find(".admin-flags .flagged-post").length,
    0,
    "post was removed"
  );
});

QUnit.test("flagged posts - agree + hide", async assert => {
  const agreeFlag = selectKit(".agree-flag");

  await visit("/admin/flags/active");

  await agreeFlag.expand();
  await agreeFlag.selectRowByValue("confirm-agree-hide");

  assert.equal(
    find(".admin-flags .flagged-post").length,
    0,
    "post was removed"
  );
});

QUnit.test("flagged posts - agree + deleteSpammer", async assert => {
  const agreeFlag = selectKit(".agree-flag");

  await visit("/admin/flags/active");

  await agreeFlag.expand();
  await agreeFlag.selectRowByValue("delete-spammer");

  await click(".confirm-delete");

  assert.equal(
    find(".admin-flags .flagged-post").length,
    0,
    "post was removed"
  );
});

QUnit.test("flagged posts - disagree", async assert => {
  await visit("/admin/flags/active");
  await click(".disagree-flag");

  assert.equal(find(".admin-flags .flagged-post").length, 0);
});

QUnit.test("flagged posts - defer", async assert => {
  await visit("/admin/flags/active");
  await click(".defer-flag");

  assert.equal(find(".admin-flags .flagged-post").length, 0);
});

QUnit.test("flagged posts - delete + defer", async assert => {
  const deleteFlag = selectKit(".delete-flag");

  await visit("/admin/flags/active");

  await deleteFlag.expand();
  await deleteFlag.selectRowByValue("delete-defer");

  assert.equal(find(".admin-flags .flagged-post").length, 0);
});

QUnit.test("flagged posts - delete + agree", async assert => {
  const deleteFlag = selectKit(".delete-flag");

  await visit("/admin/flags/active");

  await deleteFlag.expand();
  await deleteFlag.selectRowByValue("delete-agree");

  assert.equal(find(".admin-flags .flagged-post").length, 0);
});

QUnit.test("flagged posts - delete + deleteSpammer", async assert => {
  const deleteFlag = selectKit(".delete-flag");

  await visit("/admin/flags/active");

  await deleteFlag.expand();
  await deleteFlag.selectRowByValue("delete-spammer");

  await click(".confirm-delete");

  assert.equal(find(".admin-flags .flagged-post").length, 0);
});

QUnit.test("topics with flags", async assert => {
  await visit("/admin/flags/topics");

  assert.equal(find(".flagged-topics .flagged-topic").length, 1);
  assert.equal(find(".flagged-topic .flagged-topic-user").length, 2);
  assert.equal(find(".flagged-topic div.flag-counts").length, 3);

  await click(".flagged-topic .show-details");

  assert.equal(currentURL(), "/admin/flags/topics/280");
});
