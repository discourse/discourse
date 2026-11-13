import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Theme from "discourse/admin/models/theme";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Unit | Controller | admin-customize-themes-show-index",
  function (hooks) {
    setupTest(hooks);

    test("displays settings editor button with settings", function (assert) {
      const theme = Theme.create({
        id: 2,
        default: true,
        name: "default",
        settings: [{}],
      });
      const controller = this.owner.lookup(
        "controller:admin-customize-themes.show.index"
      );
      controller.setProperties({ model: theme });
      assert.true(
        controller.hasSettings,
        "sets the hasSettings property to true with settings"
      );
    });

    test("hides settings editor button with no settings", function (assert) {
      const theme = Theme.create({
        id: 2,
        default: true,
        name: "default",
        settings: [],
      });
      const controller = this.owner.lookup(
        "controller:admin-customize-themes.show.index"
      );
      controller.setProperties({ model: theme });
      assert.false(
        controller.hasSettings,
        "sets the hasSettings property to true with settings"
      );
    });

    test("only the latest locale request can replace translations or clear loading", async function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-customize-themes.show.index"
      );
      const theme = Theme.create({
        id: 7,
        translations: [],
        translations_locale: "fr",
      });
      const requests = [];
      pretender.get(
        "/admin/themes/7/translations/:locale",
        (request) => {
          requests.push(request);
          return response({
            translations: [
              { key: "greeting", value: `Response ${requests.length}` },
            ],
          });
        },
        true
      );
      controller.set("model", theme);
      controller.updateLocale("en");
      await waitUntil(() => requests.length === 1);
      controller.updateLocale("fr");
      await waitUntil(() => requests.length === 2);
      controller.updateLocale("en");
      await waitUntil(() => requests.length === 3);
      pretender.resolve(requests[0]);
      await waitUntil(() => pretender.requestReferences.length === 2);
      assert.true(
        theme.loadingTranslations,
        "an old response leaves the current request loading"
      );
      pretender.resolve(requests[2]);
      await waitUntil(() => controller.translations[0]?.value === "Response 3");
      pretender.resolve(requests[1]);
      await settled();

      assert.strictEqual(controller.translations[0].value, "Response 3");
      assert.strictEqual(theme.translations_locale, "en");
      assert.false(theme.loadingTranslations);
    });

    test("a stale failed request cannot roll back a newer locale selection", async function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-customize-themes.show.index"
      );
      const theme = Theme.create({
        id: 7,
        translations: [{ key: "greeting", value: "Original" }],
        translations_locale: "en",
      });
      let oldRequest;
      pretender.get(
        "/admin/themes/7/translations/en",
        (request) => {
          oldRequest = request;
          return response(422, { errors: ["Old request failed"] });
        },
        true
      );
      pretender.get("/admin/themes/7/translations/fr", () =>
        response({ translations: [{ key: "greeting", value: "Bonjour" }] })
      );
      controller.set("model", theme);
      controller.updateLocale("en");
      await waitUntil(() => oldRequest);
      await controller.updateLocale("fr");
      pretender.resolve(oldRequest);
      await settled();

      assert.strictEqual(theme.locale, "fr");
      assert.strictEqual(theme.translations_locale, "fr");
      assert.strictEqual(controller.translations[0].value, "Bonjour");
    });

    test("failed translation requests clear loading and show the error", async function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-customize-themes.show.index"
      );
      const theme = Theme.create({
        id: 7,
        translations: [{ key: "greeting", value: "Original" }],
        translations_locale: "en",
      });
      controller.set("model", theme);
      pretender.get("/admin/themes/7/translations/fr", () =>
        response(422, { errors: ["Cannot load translations"] })
      );
      await controller.updateLocale("fr");
      await settled();

      assert.false(theme.loadingTranslations);
      assert.strictEqual(controller.translations[0].value, "Original");
      assert.strictEqual(
        theme.locale,
        "en",
        "the selector matches the unchanged rows after failure"
      );
      assert.true(
        this.owner
          .lookup("service:dialog")
          .message.includes("Cannot load translations")
      );
    });
  }
);
