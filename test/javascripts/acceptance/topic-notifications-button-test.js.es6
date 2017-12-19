import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic Notifications button", {
  loggedIn: true,
  beforeEach() {
    const response = object => {
      return [
        200,
        { "Content-Type": "application/json" },
        object
      ];
    };

    server.post('/t/280/notifications', () => { // eslint-disable-line no-undef
      return response({});
    });
  }
});

QUnit.test("Updating topic notification level", assert => {
  visit("/t/internationalization-localization/280");

  const notificationOptions = "#topic-footer-buttons .topic-notifications-options";

  andThen(() => {
    assert.ok(
      exists(`${notificationOptions}`),
      "it should display the notification options button in the topic's footer"
    );
  });

  expandSelectKit(notificationOptions);
  selectKitSelectRow("3", { selector: notificationOptions});

  andThen(() => {
    assert.equal(
      selectKit(notificationOptions).selectedRow.name(),
      "watching",
      "it should display the right notification level"
    );

    assert.equal(
      find(`.timeline-footer-controls .select-kit-header`).data().name,
      'Watching',
      'it should display the right notification level in topic timeline'
    );
  });
});
