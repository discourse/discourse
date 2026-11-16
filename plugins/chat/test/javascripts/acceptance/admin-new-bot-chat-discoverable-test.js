import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

[true, false].forEach((chatEnabled) => {
  acceptance(
    `Admin - New bot chat discovery - chat ${chatEnabled ? "enabled" : "disabled"}`,
    function (needs) {
      needs.user({ admin: true });
      needs.settings({ chat_enabled: chatEnabled });

      let payload;
      needs.pretender((server, helper) => {
        server.get("/admin/users/bots/new.json", () =>
          helper.response({ default_trust_level: 1, name_required: false })
        );
        server.get("/admin/api/keys/scopes.json", () =>
          helper.response({ scopes: {} })
        );
        server.get("/admin/users/list/bots.json", () => helper.response([]));
        server.post("/admin/users/bots.json", (request) => {
          payload = JSON.parse(request.requestBody);
          return helper.response(201, { user: { id: -200, ...payload.bot } });
        });
      });

      test("discovery is opt-in and only offered while chat is enabled", async function (assert) {
        await visit("/admin/users/bots/new");
        assert
          .dom('[data-name="chat_discoverable"] input')
          .exists({ count: chatEnabled ? 1 : 0 });

        const form = formKit(".admin-bot-form");
        await form.field("username").fillIn("test_bot");
        await form.submit();

        assert.strictEqual(
          payload.bot.chat_discoverable,
          chatEnabled ? false : undefined
        );
      });
    }
  );
});
