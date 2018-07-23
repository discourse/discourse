import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Notifications button", {
  loggedIn: true,
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.post("/t/280/notifications", () => { // eslint-disable-line no-undef
      return response({});
    });
  }
});

QUnit.test("Updating topic notification level", async assert => {
  const notificationOptions = selectKit(
    "#topic-footer-buttons .topic-notifications-options"
  );

  await visit("/t/internationalization-localization/280");

  assert.ok(
    notificationOptions.exists(),
    "it should display the notification options button in the topic's footer"
  );

  await notificationOptions.expandAwait();
  await notificationOptions.selectRowByValueAwait("3");

  assert.equal(
    notificationOptions.selectedRow().name(),
    "Watching",
    "it should display the right notification level"
  );
});
