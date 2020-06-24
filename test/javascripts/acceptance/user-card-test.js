import { acceptance } from "helpers/qunit-helpers";
import DiscourseURL from "discourse/lib/url";

import pretender from "helpers/create-pretender";
import userFixtures from "fixtures/user_fixtures";
import User from "discourse/models/user";

acceptance("User Card - Show Local Time", {
  loggedIn: true,
  settings: { display_local_time_in_user_card: true }
});

QUnit.skip("user card local time", async assert => {
  User.current().changeTimezone("Australia/Brisbane");
  let cardResponse = _.clone(userFixtures["/u/eviltrout/card.json"]);
  cardResponse.user.timezone = "Australia/Perth";

  pretender.get("/u/eviltrout/card.json", () => [
    200,
    { "Content-Type": "application/json" },
    cardResponse
  ]);

  await visit("/t/internationalization-localization/280");
  assert.ok(invisible(".user-card"), "user card is invisible by default");
  await click("a[data-user-card=eviltrout]:first");

  let expectedTime = moment
    .tz("Australia/Brisbane")
    .add(-2, "hours")
    .format("h:mm a");

  assert.ok(visible(".user-card"), "card should appear");
  assert.equal(
    find(".user-card .local-time")
      .text()
      .trim(),
    expectedTime,
    "user card contains the user's local time"
  );

  cardResponse = _.clone(userFixtures["/u/charlie/card.json"]);
  cardResponse.user.timezone = "America/New_York";

  pretender.get("/u/charlie/card.json", () => [
    200,
    { "Content-Type": "application/json" },
    cardResponse
  ]);

  await click("a[data-user-card=charlie]:first");

  expectedTime = moment
    .tz("Australia/Brisbane")
    .add(-14, "hours")
    .format("h:mm a");

  assert.equal(
    find(".user-card .local-time")
      .text()
      .trim(),
    expectedTime,
    "opening another user card updates the local time in the card (no caching)"
  );
});

QUnit.test(
  "user card local time - does not update timezone for another user",
  async assert => {
    User.current().changeTimezone("Australia/Brisbane");
    let cardResponse = _.clone(userFixtures["/u/charlie/card.json"]);
    delete cardResponse.user.timezone;

    pretender.get("/u/charlie/card.json", () => [
      200,
      { "Content-Type": "application/json" },
      cardResponse
    ]);

    await visit("/t/internationalization-localization/280");
    await click("a[data-user-card=charlie]:first");

    assert.not(
      exists(".user-card .local-time"),
      "it does not show the local time if the user card returns a null/undefined timezone for another user"
    );
  }
);

acceptance("User Card", { loggedIn: true });

QUnit.skip("user card", async assert => {
  await visit("/t/internationalization-localization/280");
  assert.ok(invisible(".user-card"), "user card is invisible by default");

  await click("a[data-user-card=eviltrout]:first");
  assert.ok(visible(".user-card"), "card should appear");
  assert.equal(
    find(".user-card .username")
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
  assert.ok(visible(".user-card"), "card should appear");
  assert.equal(
    find(".user-card .username")
      .text()
      .trim(),
    "charlie",
    "user card contains the data"
  );

  assert.ok(
    !visible(".user-card .local-time"),
    "local time with zone does not show by default"
  );

  await click(".card-content .compose-pm button");
  assert.ok(
    invisible(".user-card"),
    "user card dismissed after hitting Message button"
  );

  const mention = find("a.mention");
  const icon = document.createElement("span");
  icon.classList.add("icon");
  mention.append(icon);
  await click("a.mention .icon");
  assert.ok(visible(".user-card"), "card should appear");
  assert.equal(
    find(".user-card .username")
      .text()
      .trim(),
    "eviltrout",
    "user card contains the data"
  );
});
