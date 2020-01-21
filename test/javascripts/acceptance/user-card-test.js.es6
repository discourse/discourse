import { acceptance } from "helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";

acceptance("User Card", { loggedIn: true });

QUnit.test("user card", async assert => {
  await visit("/t/internationalization-localization/280");
  assert.ok(invisible("#user-card"), "user card is invisible by default");

  await click("a[data-user-card=eviltrout]:first");
  assert.ok(visible("#user-card"), "card should appear");
  assert.equal(
    find("#user-card .username")
      .text()
      .trim(),
    "eviltrout",
    "user card contains the data"
  );

  sandbox.stub(DiscourseURL, "routeTo");
  await click(".card-content a.user-profile-link");
  assert.ok(
    DiscourseURL.routeTo.calledWith("/u/eviltrout"),
    "it should navigate to the user profile"
  );

  await click("a[data-user-card=charlie]:first");
  assert.ok(visible("#user-card"), "card should appear");
  assert.equal(
    find("#user-card .username")
      .text()
      .trim(),
    "charlie",
    "user card contains the data"
  );

  await click(".card-content .compose-pm button");
  assert.ok(
    invisible("#user-card"),
    "user card dismissed after hitting Message button"
  );

  const mention = find("a.mention");
  const icon = document.createElement("span");
  icon.classList.add("icon");
  mention.append(icon);
  await click("a.mention .icon");
  assert.ok(visible("#user-card"), "card should appear");
  assert.equal(
    find("#user-card .username")
      .text()
      .trim(),
    "eviltrout",
    "user card contains the data"
  );
});
