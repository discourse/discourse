import {
  click,
  currentURL,
  resetOnerror,
  settled,
  setupOnerror,
  triggerEvent,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { setPrefix } from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance, currentUser } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const NEW_BOT_BUTTON = ".admin-users__subheader-new-bot";
const FORM = ".admin-bot-form";

acceptance("Admin - New bot", function (needs) {
  needs.user({ admin: true });

  let defaultTrustLevel;
  let nameRequired;
  let payloads;
  let listQueries;
  let createdUser;
  let failCreation;

  needs.pretender((server, helper) => {
    defaultTrustLevel = 2;
    nameRequired = false;
    payloads = [];
    listQueries = [];
    createdUser = null;
    failCreation = false;

    ["", "/forum"].forEach((prefix) => {
      server.get(`${prefix}/session/csrf`, () =>
        helper.response({ csrf: "test-csrf-token" })
      );

      server.get(`${prefix}/admin/users/bots/new.json`, () =>
        helper.response({
          default_trust_level: defaultTrustLevel,
          name_required: nameRequired,
        })
      );

      server.get(
        `${prefix}/admin/users/bots/username_suggestion.json`,
        (request) =>
          helper.response({
            username: request.queryParams.name
              .toLowerCase()
              .replace(/\s+/g, "_"),
          })
      );

      server.get(`${prefix}/admin/api/keys/scopes.json`, () =>
        helper.response({
          scopes: {
            global: [
              {
                scope_id: "global:read",
                key: "read",
                name: "read",
                params: null,
                urls: [],
              },
            ],
            topics: [
              {
                scope_id: "topics:write",
                key: "write",
                name: "write",
                params: ["topic_id"],
                urls: [],
              },
            ],
          },
        })
      );

      server.get(`${prefix}/admin/users/list/bots.json`, (request) => {
        listQueries.push(request.queryParams);
        return helper.response(
          createdUser && !request.queryParams.filter
            ? [
                {
                  ...createdUser,
                  bot_creator: {
                    username: currentUser().username,
                    url: `/admin/users/${currentUser().id}/${currentUser().username}`,
                  },
                },
              ]
            : []
        );
      });

      server.post(`${prefix}/admin/users/bots.json`, (request) => {
        const payload = JSON.parse(request.requestBody);
        payloads.push(payload);

        if (failCreation) {
          return helper.response(422, {
            errors: ["Username has already been taken"],
          });
        }

        createdUser = { id: -200, ...payload.bot };
        return helper.response(201, {
          user: createdUser,
          ...(payload.key && {
            key: {
              key: "generated-secret-key",
              description: payload.bot.username,
            },
          }),
        });
      });
    });
  });

  test("offers a menu explaining each path when other bot flows are registered", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("admin-new-bot-options", ({ value }) => [
        ...value,
        {
          id: "other",
          icon: "key",
          label: "admin.api.new_key",
          description: "admin.users.bots.help",
          route: "adminApiKeys.new",
        },
      ]);
    });

    const dropdown = selectKit(NEW_BOT_BUTTON);

    await visit("/admin/users/list/bots");
    await dropdown.expand();

    assert.strictEqual(
      dropdown.rows().length,
      2,
      "lists the generic bot and the registered flow"
    );
    assert.strictEqual(
      dropdown.rowByValue("bot").label(),
      i18n("admin.users.bots.new_options.bot.label")
    );
    assert.strictEqual(
      dropdown.rowByValue("bot").description(),
      i18n("admin.users.bots.new_options.bot.description"),
      "explains when to choose each path"
    );

    await dropdown.selectRowByValue("other");
    assert.strictEqual(
      currentURL(),
      "/admin/api/keys/new",
      "opens the registered flow"
    );

    await visit("/admin/users/list/bots");
    await dropdown.expand();
    await dropdown.selectRowByValue("bot");
    assert.strictEqual(
      currentURL(),
      "/admin/users/bots/new",
      "opens the generic bot form"
    );
  });

  test("only the Bots subheader has the primary creation action", async function (assert) {
    await visit("/admin/users/list/bots");

    assert
      .dom(NEW_BOT_BUTTON)
      .hasText(i18n("admin.users.bots.new"), "admins see the creation action");
    assert
      .dom(NEW_BOT_BUTTON)
      .hasClass("btn-primary", "creation is the primary action");

    await click(NEW_BOT_BUTTON);
    assert.strictEqual(
      currentURL(),
      "/admin/users/bots/new",
      "the action opens the dedicated page"
    );

    await click(".back-button");
    await click(".admin-users-tabs__active a");
    assert
      .dom(NEW_BOT_BUTTON)
      .doesNotExist("other user lists have no creation action");
  });

  test("the form loads directly without the Users page shell", async function (assert) {
    await visit("/admin/users/bots/new");

    assert.dom(FORM).exists("the form is directly loadable");
    assert
      .dom(".admin-users")
      .doesNotExist("the Users header and tabs are not inherited");
    assert
      .dom(".admin-config-area-card__title")
      .hasText(
        i18n("admin.users.bots.new"),
        "the card has a localized heading"
      );
    assert
      .dom(".admin-config-area-card__description")
      .hasText(
        i18n("admin.users.bots.help"),
        "the account-only boundary is explained"
      );
    assert
      .dom(".back-button")
      .hasAttribute("href", "/admin/users/list/bots", "back returns to Bots");
    assert.deepEqual(
      formKit(FORM).field("trust_level").options(),
      ["0", "1", "2", "3", "4"],
      "all five trust levels are available"
    );
    assert
      .form(FORM)
      .field("trust_level")
      .hasValue("2", "the site default trust level is selected");
    assert
      .dom(`${FORM} [data-name]`)
      .exists(
        { count: 4 },
        "only name, username, trust level and the API key toggle are editable"
      );
  });

  test("creates a bot with the site's default trust level and shows a success toast", async function (assert) {
    await visit("/admin/users/bots/new");
    const toasts = this.owner.lookup("service:toasts");
    const successToast = sinon.spy(toasts.success);
    sinon.replaceGetter(toasts, "success", () => successToast);
    const form = formKit(FORM);
    await form.field("name").fillIn("Release helper");
    await form.field("username").fillIn("release_helper");
    await form.submit();

    assert.deepEqual(
      payloads,
      [
        {
          bot: {
            name: "Release helper",
            username: "release_helper",
            trust_level: 2,
          },
        },
      ],
      "one narrow bot payload is submitted"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots?order=created",
      "success returns to newest-first Bots"
    );
    assert
      .dom(".directory-table__cell.username")
      .includesText("release_helper", "the new bot is visible in the list");
    assert.true(successToast.calledOnce, "creation shows one success toast");
    assert.strictEqual(
      successToast.firstCall.args[0].data.message,
      i18n("admin.users.bots.created", { username: "release_helper" }),
      "the success toast identifies the created bot"
    );
    assert
      .dom(".admin-users-list__source-values")
      .hasText(
        currentUser().username,
        "a manual bot identifies its creator in Source"
      );
  });

  test("suggests a username from the name until one is typed", async function (assert) {
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);

    await form.field("name").fillIn("Release helper");
    await settled();
    assert
      .form(FORM)
      .field("username")
      .hasValue("release_helper", "the username follows the name");

    await form.field("name").fillIn("Deploy helper");
    await settled();
    assert
      .form(FORM)
      .field("username")
      .hasValue("deploy_helper", "the suggestion updates with the name");

    await form.field("username").fillIn("custom_bot");
    await form.field("name").fillIn("Another helper");
    await settled();
    assert
      .form(FORM)
      .field("username")
      .hasValue("custom_bot", "a typed username is kept");
  });

  test("clearing the name clears a suggested username only", async function (assert) {
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);

    await form.field("name").fillIn("Release helper");
    await settled();
    await form.field("name").fillIn("");
    await settled();
    assert
      .form(FORM)
      .field("username")
      .hasValue("", "the suggested username is cleared");

    await form.field("username").fillIn("custom_bot");
    await form.field("name").fillIn("Release helper");
    await form.field("name").fillIn("");
    await settled();
    assert
      .form(FORM)
      .field("username")
      .hasValue("custom_bot", "a typed username is kept");
  });

  test("can generate an API key that is shown once", async function (assert) {
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    await form.field("username").fillIn("release_helper");

    assert
      .form(FORM)
      .field("scope_mode")
      .doesNotExist("key fields stay hidden until requested");

    await form.field("generate_api_key").toggle();
    await form.field("scope_mode").select("read_only");
    await form.submit();

    assert.deepEqual(
      payloads[0].key,
      {
        scope_mode: "read_only",
        scopes: [
          {
            scope_id: "global:read",
            key: "read",
            name: "read",
            params: null,
            urls: [],
          },
        ],
      },
      "the key request is sent alongside the bot"
    );
    assert
      .dom(".generated-api-key")
      .hasText("generated-secret-key", "the new key is shown");
    assert.strictEqual(
      currentURL(),
      "/admin/users/bots/new",
      "the key stays on screen until dismissed"
    );

    await click(".admin-bot-form__back");

    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots?order=created",
      "back returns to newest-first Bots"
    );
  });

  test("a granular key requires at least one scope", async function (assert) {
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    await form.field("username").fillIn("release_helper");
    await form.field("generate_api_key").toggle();
    await form.field("scope_mode").select("granular");
    await form.submit();

    assert.deepEqual(payloads, [], "nothing is submitted");
    assert
      .form(FORM)
      .hasErrors(
        { scopes: i18n("admin.api.scopes.one_or_more") },
        "the missing scope is reported"
      );
  });

  test("submits the selected trust level including level zero", async function (assert) {
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    await form.field("username").fillIn("custom_bot");
    await form.field("trust_level").select("0");
    await form.submit();

    assert.deepEqual(
      payloads,
      [{ bot: { name: "", username: "custom_bot", trust_level: 0 } }],
      "the explicit trust level is sent without extra fields"
    );
  });

  test("the admin metadata can default to trust level zero", async function (assert) {
    defaultTrustLevel = 0;
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    assert
      .form(FORM)
      .field("trust_level")
      .hasValue("0", "zero is selected rather than a placeholder");
    await form.field("username").fillIn("default_zero_bot");
    await form.submit();

    assert.strictEqual(
      payloads[0].bot.trust_level,
      0,
      "the zero default is valid and submitted"
    );
  });

  test("the admin metadata can require a name", async function (assert) {
    nameRequired = true;
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    await form.field("username").fillIn("named_bot");
    await form.submit();

    assert
      .form(FORM)
      .hasErrors(
        { name: i18n("form_kit.errors.required") },
        "the site name policy is validated inline"
      );
    assert.strictEqual(
      payloads.length,
      0,
      "a required name is not submitted blank"
    );
    await form.field("name").fillIn("Named bot");
    await form.submit();
    assert.strictEqual(
      payloads[0].bot.name,
      "Named bot",
      "adding a name allows submission"
    );
  });

  test("requires a valid username before submitting", async function (assert) {
    await visit("/admin/users/bots/new");
    await formKit(FORM).submit();

    assert
      .form(FORM)
      .hasErrors(
        { username: i18n("form_kit.errors.required") },
        "required username validation is inline"
      );
    assert.strictEqual(payloads.length, 0, "invalid data is not submitted");
  });

  test("server validation errors stay inline and allow correction and retry", async function (assert) {
    failCreation = true;
    await visit("/admin/users/bots/new");
    const form = formKit(FORM);
    await form.field("name").fillIn("Release helper");
    await form.field("username").fillIn("taken_bot");
    await form.submit();

    assert.strictEqual(
      currentURL(),
      "/admin/users/bots/new",
      "an error does not navigate away"
    );
    assert
      .dom(`${FORM} .form-kit__errors-summary`)
      .includesText(
        "Username has already been taken",
        "server errors are displayed in the form"
      );
    assert
      .form(FORM)
      .field("name")
      .hasValue("Release helper", "the entered name is retained");
    assert
      .form(FORM)
      .field("username")
      .hasValue("taken_bot", "the entered username is retained");
    assert
      .dom(`${FORM} button[type=submit]`)
      .isEnabled("submission is enabled after the request fails");

    failCreation = false;
    await form.field("username").fillIn("available_bot");
    await form.submit();
    assert.strictEqual(payloads.length, 2, "the corrected form can be retried");
    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots?order=created",
      "the retry succeeds"
    );
  });

  test("back cancels without creating an account and re-entry starts fresh", async function (assert) {
    await visit("/admin/users/bots/new");
    await formKit(FORM).field("username").fillIn("unsaved_bot");
    await click(".back-button");
    await click(".dialog-footer .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots",
      "discarding the draft returns to Bots"
    );
    assert.strictEqual(payloads.length, 0, "back does not create an account");

    await click(NEW_BOT_BUTTON);
    assert
      .form(FORM)
      .field("username")
      .hasNoValue("a new visit has no stale username");
    assert
      .form(FORM)
      .field("trust_level")
      .hasValue("2", "a new visit restores the site default");
  });

  test("cancel returns to Bots without creating an account", async function (assert) {
    await visit("/admin/users/bots/new");
    await formKit(FORM).field("username").fillIn("cancelled_bot");
    await click(".admin-bot-form__cancel");
    await click(".dialog-footer .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots",
      "cancel returns to Bots after discarding the draft"
    );
    assert.strictEqual(payloads.length, 0, "cancel does not create an account");
  });

  ["", "/forum"].forEach((prefix) => {
    test(`creation clears stale search, sorting and account-type state (prefix: "${prefix}")`, async function (assert) {
      setPrefix(prefix);
      // The router service cannot configure the test location’s root URL.
      // eslint-disable-next-line ember/no-private-routing-service
      this.owner.lookup("router:main").rootURL = `${prefix}/`;
      await visit(
        "/admin/users/list/bots?filter=missing&username=old_bot&order=username&asc=true&account_type=human&activation=not_activated"
      );
      await click(NEW_BOT_BUTTON);
      assert
        .dom(".back-button")
        .hasAttribute(
          "href",
          `${prefix}/admin/users/list/bots?username=old_bot`,
          "router-generated links include the subfolder"
        );
      const form = formKit(FORM);
      await form.field("username").fillIn("visible_bot");
      await form.submit();

      assert.strictEqual(
        currentURL(),
        "/admin/users/list/bots?order=created",
        "stale query parameters are removed"
      );
      const query = listQueries.at(-1);
      assert.strictEqual(
        query.order,
        "created",
        "Bots is fetched newest first"
      );
      for (const key of [
        "filter",
        "username",
        "asc",
        "account_type",
        "activation",
      ]) {
        assert.false(Boolean(query[key]), `${key} does not hide the new bot`);
      }
      assert.strictEqual(query.page, "1", "the first page is fetched");
      assert
        .dom(".directory-table__cell.username")
        .includesText(
          "visible_bot",
          "the created bot is not hidden by stale filters"
        );
      assert
        .dom(".d-filter-controls input")
        .hasNoValue("the search control is reset");
    });
  });

  test("awaits creation and prevents duplicate pending submissions", async function (assert) {
    let pendingRequest;
    pretender.post(
      "/admin/users/bots.json",
      (request) => {
        pendingRequest = request;
        payloads.push(request.requestBody);
        return [
          201,
          { "Content-Type": "application/json" },
          JSON.stringify({ user: { id: -201, username: "pending_bot" } }),
        ];
      },
      true
    );

    await visit("/admin/users/bots/new");
    await formKit(FORM).field("username").fillIn("pending_bot");
    const submission = formKit(FORM).submit();
    await waitUntil(() => pendingRequest);
    await waitFor(`${FORM} button[type=submit][disabled]`);

    assert.strictEqual(
      currentURL(),
      "/admin/users/bots/new",
      "navigation waits for creation"
    );
    assert
      .dom(`${FORM} button[type=submit]`)
      .isDisabled("the submit button is disabled while pending");
    const duplicate = triggerEvent(FORM, "submit");
    assert.strictEqual(payloads.length, 1, "only one request is pending");

    pretender.resolve(pendingRequest);
    await Promise.all([submission, duplicate]);
    await settled();
    assert.strictEqual(
      payloads.length,
      1,
      "a duplicate submit does not create another bot"
    );
    assert.strictEqual(
      currentURL(),
      "/admin/users/list/bots?order=created",
      "creation completes normally"
    );
  });
});

acceptance("Admin - New bot - moderator", function (needs) {
  needs.user({ admin: false, moderator: true });

  let metadataRequests;
  needs.pretender((server, helper) => {
    metadataRequests = 0;
    server.get("/admin/users/bots/new.json", () => {
      metadataRequests++;
      return helper.response(403, { errors: [i18n("errors.desc.forbidden")] });
    });
    server.get("/admin/users/list/bots.json", () => helper.response([]));
  });

  test("moderators can list bots but cannot see the creation action", async function (assert) {
    await visit("/admin/users/list/bots");
    assert
      .dom(".admin-users-tabs__bots")
      .exists("moderators can access the Bots list");
    assert
      .dom(NEW_BOT_BUTTON)
      .doesNotExist("moderators have no creation action");
  });

  test("moderators cannot load the form by navigating directly", async function (assert) {
    setupOnerror(() => {});
    try {
      await visit("/admin/users/bots/new");
    } catch {}
    await settled();
    resetOnerror();
    assert.dom(FORM).doesNotExist("the creation form is not rendered");
    assert
      .dom(".error-page .reason")
      .hasText(i18n("errors.reasons.forbidden"), "direct access is forbidden");
    assert
      .dom(".error-page .desc")
      .hasText(
        i18n("errors.desc.forbidden"),
        "the admin requirement is explained"
      );
    assert.strictEqual(
      metadataRequests,
      1,
      "the server rejects access to admin metadata"
    );
  });
});
