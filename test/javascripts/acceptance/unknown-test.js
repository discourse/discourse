import { acceptance } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";
acceptance("Unknown");

QUnit.test("Permalink Unknown URL", async assert => {
  await visit("/url-that-doesn't-exist");
  assert.ok(exists(".page-not-found"), "The not found content is present");
});

QUnit.test("Permalink URL to a Topic", async assert => {
  pretender.get("/permalink-check.json", () => {
    return [
      200,
      { "Content-Type": "application/json" },
      {
        found: true,
        internal: true,
        target_url: "/t/internationalization-localization/280"
      }
    ];
  });

  await visit("/viewtopic.php?f=8&t=280");
  assert.ok(exists(".topic-post"));
});

QUnit.test("Permalink URL to a static page", async assert => {
  pretender.get("/permalink-check.json", () => {
    return [
      200,
      { "Content-Type": "application/json" },
      {
        found: true,
        internal: true,
        target_url: "/faq"
      }
    ];
  });

  await visit("/not-the-url-for-faq");

  // body is outside of #ember-testing-container and needs to be targeted
  // through document instead of find
  assert.ok(
    document.querySelector("body.static-faq"),
    "routed to the faq page"
  );
  assert.ok(exists(".body-page"));
});
