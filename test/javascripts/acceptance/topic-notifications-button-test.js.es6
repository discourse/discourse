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
      exists(`${notificationOptions} .tracking`),
      "it should display the notification options button in the topic's footer"
    );
  });

  click(`${notificationOptions} .tracking`);
  click(`${notificationOptions} .select-box-collection .select-box-row[title=tracking]`);

  andThen(() => {
    assert.ok(
      exists(`${notificationOptions} .watching`),
      "it should display the right notification level"
    );

    // TODO: tgxworld I can't figure out why the topic timeline doesn't show when
    // running the tests in phantomjs
    // ok(
    //   exists(".timeline-footer-controls .notifications-button .watching"),
    //   'it should display the right notification level in topic timeline'
    // );
  });
});
