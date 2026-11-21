import { click, currentURL, fillIn, select, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Events | Admin submissions", function (needs) {
  needs.user({ admin: true });
  needs.settings({
    discourse_events_enabled: true,
    discourse_post_event_enabled: true,
  });

  const base = "/admin/plugins/discourse-events";

  needs.pretender((server) => {
    server.get(base + ".json", () =>
      response({
        id: "discourse-events",
        name: "discourse-events",
        humanized_name: "Events",
        enabled: true,
        has_settings: true,
        admin_route: { use_new_show_route: true, location: "discourse-events" },
      })
    );
  });

  test("shows event-level counts and offers report actions for hosted events", async function (assert) {
    pretender.get(base + "/submissions.json", (request) =>
      response({
        events:
          request.queryParams.page === "2"
            ? []
            : [
                {
                  id: 4,
                  url: "/t/workshop/4",
                  title: "Workshop",
                  hosts: [
                    {
                      username: "alice",
                      avatar_template: "/avatars/alice/{size}.png",
                    },
                    {
                      username: "bob",
                      avatar_template: "/avatars/bob/{size}.png",
                    },
                  ],
                  form_title: "Signup",
                  submission_count: 2,
                  latest_submission_at: "2026-11-19T00:00:00Z",
                  can_export: true,
                  report_topic_id: 7,
                },
                {
                  id: 8,
                  url: "/t/lunch/8",
                  title: "Lunch",
                  hosts: [
                    {
                      username: "carol",
                      avatar_template: "/avatars/carol/{size}.png",
                    },
                  ],
                  form_title: "Meal choices",
                  submission_count: 0,
                  can_export: false,
                },
              ],
        next_page: request.queryParams.page === "2" ? null : 2,
        previous_page: request.queryParams.page === "2" ? 1 : null,
      })
    );
    pretender.post("/export_csv/export_entity.json", (request) => {
      const params = new URLSearchParams(request.requestBody);
      assert.strictEqual(params.get("entity"), "event_registrations");
      assert.strictEqual(params.get("args[id]"), "4");
      return response({ success: "OK" });
    });
    await visit(base + "/submissions");
    assert.dom("tbody tr").exists({ count: 2 });
    assert.dom("tbody tr:first-child").includesText("Workshop");
    assert
      .dom('tbody tr:first-child a[data-user-card="alice"]')
      .hasText("alice");
    assert.dom('tbody tr:first-child a[data-user-card="bob"]').hasText("bob");
    for (const username of ["alice", "bob", "carol"]) {
      assert
        .dom(`a[data-user-card="${username}"] img.avatar`)
        .hasAttribute("src", new RegExp(`/avatars/${username}/\\d+\\.png$`));
    }
    assert
      .dom('tbody tr:last-child a[data-user-card="carol"]')
      .hasText("carol");
    assert.dom("tbody tr:last-child button").doesNotExist();
    assert.dom('.dropdown-menu a[href="/t/-/7"]').doesNotExist();
    await click(
      'tbody tr:first-child button[aria-label="Report actions for Workshop"]'
    );
    assert.dom('.dropdown-menu a[href="/t/-/7"]').hasText("View PM");
    assert.dom(".dropdown-menu button").hasText("Download CSV");
    await click(".dropdown-menu button");
    assert
      .dom(".dialog-body")
      .hasText(i18n("event_registration.export_queued"));
    await click("#dialog-holder .btn-primary");
    await click('a[href*="page=2"]');
    assert.dom(".admin-config-area-empty-list").exists();
  });

  test("combines the name search with the form dropdown and keeps both in the URL", async function (assert) {
    pretender.get("/discourse-post-event/registration-forms.json", () =>
      response({ registration_forms: [{ id: 5, title: "Conference signup" }] })
    );
    const requests = [];
    pretender.get(base + "/submissions.json", ({ queryParams }) => {
      requests.push(queryParams);
      return response({
        events:
          queryParams.search === "missing"
            ? []
            : [
                {
                  id: 9,
                  title: "Annual conference",
                  form_title: "Conference signup",
                  url: "/t/conference/9",
                  submission_count: 0,
                },
              ],
        previous_page: queryParams.page === "2" ? 1 : null,
        next_page:
          queryParams.page === "2" || queryParams.search === "missing"
            ? null
            : 2,
      });
    });
    await visit(base + "/submissions?form_id=5&page=2&search=conference");
    const input = ".event-registration-submissions__filters input";
    const dropdown = ".d-filter-controls__dropdown";
    assert
      .dom(input)
      .hasValue("conference")
      .hasAttribute("aria-label", "Search by event or form name");
    assert.dom(dropdown).hasValue("5");
    await fillIn(input, "signup");
    assert.deepEqual(requests.at(-1), {
      form_id: "5",
      page: "1",
      search: "signup",
    });
    assert.dom("tbody tr").includesText("Conference signup");
    await click('a[href*="page=2"]');
    assert.deepEqual(requests.at(-1), {
      form_id: "5",
      page: "2",
      search: "signup",
    });
    await select(dropdown, "all");
    assert.deepEqual(requests.at(-1), { page: "1", search: "signup" });
    await fillIn(input, "missing");
    assert
      .dom(".admin-config-area-empty-list")
      .includesText("No events match your search.");
    await click(".filter-input-clear-btn");
    assert.strictEqual(currentURL(), base + "/submissions");
    assert.dom(input).hasValue("");
    assert.dom("tbody tr").exists();
  });
});
