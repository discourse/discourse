import Service from "@ember/service";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AdminCommandCenter from "discourse/admin/components/admin-command-center";
import AdminUser from "discourse/admin/models/admin-user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | AdminCommandCenter", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
  });

  hooks.beforeEach(function () {
    this.userSearchRequests = 0;

    pretender.get("/admin/command-center/users.json", (request) => {
      this.userSearchRequests += 1;

      if (request.queryParams.term === "mark@example.com") {
        return response({
          users: [
            {
              id: 1,
              username: "markvanlan",
              name: "Mark Vanlan",
              suspended: false,
              silenced: false,
            },
          ],
        });
      }

      return response({ users: [] });
    });
  });

  test("shows admin search results", async function (assert) {
    await render(<template><AdminCommandCenter /></template>);
    await fillIn(".admin-command-center__input", "settings");

    assert.dom(".admin-command-center__panel").exists();
    assert.dom(".admin-command-center__result").exists();
  });

  test("runs search entered before the data source is ready", async function (assert) {
    let resolveBuildMap;
    const buildMapPromise = new Promise((resolve) => {
      resolveBuildMap = resolve;
    });

    this.owner.register(
      "service:admin-search-data-source",
      class extends Service {
        buildMap() {
          return buildMapPromise;
        }

        search() {
          return [
            {
              description: "Configure the community title",
              icon: "gear",
              label: "About your site > Title",
              type: "setting",
              url: "/admin/config/about/settings?filter=title",
            },
          ];
        }
      }
    );

    await render(<template><AdminCommandCenter /></template>);
    await fillIn(".admin-command-center__input", "title");

    assert.dom(".admin-command-center__result").doesNotExist();

    resolveBuildMap();
    await settled();

    assert
      .dom(".admin-command-center__result")
      .includesText("About your site > Title");
  });

  test("builds a draft natural language plan", async function (assert) {
    await render(<template><AdminCommandCenter /></template>);
    await fillIn(
      ".admin-command-center__input",
      "I want to suspend markvanlan"
    );

    assert
      .dom(".admin-command-center__plan")
      .includesText("I’m going to suspend user markvanlan.");
    assert
      .dom(".admin-command-center__plan .btn-primary")
      .includesText("Preview action");
    assert
      .dom(".admin-command-center__plan .btn-default")
      .hasAttribute("href", "/admin/users/list/active?username=markvanlan");

    await click(".admin-command-center__continue");

    assert
      .dom(".admin-command-center__conversation")
      .includesText("This POC does not execute the change automatically.");
  });

  test("builds draft plans for reversing penalties", async function (assert) {
    await render(<template><AdminCommandCenter /></template>);
    await fillIn(".admin-command-center__input", "unsuspend markvanlan");

    assert
      .dom(".admin-command-center__plan")
      .includesText("I’m going to unsuspend user markvanlan.");

    await fillIn(".admin-command-center__input", "unsilence markvanlan");

    assert
      .dom(".admin-command-center__plan")
      .includesText("I’m going to unsilence user markvanlan.");
  });

  test("shows a validated suspension preview", async function (assert) {
    pretender.post("/admin/command-center/preview.json", () => {
      return response({
        intent: "suspend_user",
        parser: { source: "deterministic", confidence: 0.9 },
        user: { id: 1, username: "markvanlan" },
        context: {
          trust_level: 1,
          post_count: 12,
          flags_received_count: 3,
          penalty_counts: { total: 2 },
        },
        suspension: {
          suspend_until: "2026-05-29T00:00:00Z",
          duration: "7 days",
          reason: "repeated spam",
          message:
            "Your account has been temporarily suspended. Reason: repeated spam",
        },
      });
    });

    await render(<template><AdminCommandCenter /></template>);
    await fillIn(
      ".admin-command-center__input",
      "I want to suspend markvanlan"
    );
    await click(".admin-command-center__plan .btn-primary");

    assert.dom(".admin-command-center__review").includesText("markvanlan");
    assert.dom(".admin-command-center__review").includesText("repeated spam");
    assert.dom(".admin-command-center__facts").includesText("3");
  });

  test("shows user quick actions", async function (assert) {
    await render(<template><AdminCommandCenter /></template>);
    await fillIn(".admin-command-center__input", "mark@example.com");

    assert.dom(".admin-command-center__user").includesText("markvanlan");
    assert.dom(".admin-command-center__user").includesText("Mark Vanlan");
  });

  test("does not search users for natural language commands", async function (assert) {
    await render(<template><AdminCommandCenter /></template>);
    await fillIn(
      ".admin-command-center__input",
      "I want to suspend markvanlan"
    );

    assert.strictEqual(this.userSearchRequests, 0);
  });

  test("opens the suspend modal with previewed values", async function (assert) {
    const adminUser = { id: 1, adminUserView: true };
    let modalUser;
    let modalOptions;

    sinon.stub(AdminUser, "find").resolves(adminUser);
    this.owner.register(
      "service:admin-tools",
      class extends Service {
        showSuspendModal(user, options) {
          modalUser = user;
          modalOptions = options;
        }
      }
    );

    pretender.post("/admin/command-center/preview.json", () => {
      return response({
        intent: "suspend_user",
        parser: { source: "deterministic", confidence: 0.9 },
        user: { id: 1, username: "markvanlan" },
        context: {
          trust_level: 1,
          post_count: 12,
          flags_received_count: 3,
          penalty_counts: { total: 2 },
        },
        suspension: {
          suspend_until: "2026-05-29T00:00:00Z",
          duration: "7 days",
          reason: "repeated spam",
          message:
            "Your account has been temporarily suspended. Reason: repeated spam",
        },
      });
    });

    await render(<template><AdminCommandCenter /></template>);
    await fillIn(".admin-command-center__input", "suspend markvanlan");
    await click(".admin-command-center__plan .btn-primary");
    await click(".admin-command-center__review .btn-danger");

    assert.strictEqual(modalUser, adminUser);
    assert.deepEqual(modalOptions, {
      penalizeUntil: "2026-05-29T00:00:00Z",
      reason: "repeated spam",
      message:
        "Your account has been temporarily suspended. Reason: repeated spam",
    });
  });
});
