import { click, find, visit } from "@ember/test-helpers";
import { skip, test } from "qunit";
import cookie, { removeCookie } from "discourse/lib/cookie";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("User Preferences - Interface", function (needs) {
  needs.user();

  let lastUserData;
  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      lastUserData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  test("font size change", async function (assert) {
    removeCookie("text_size");

    const savePreferences = async () => {
      assert.dom(".saved").doesNotExist("hasn't been saved yet");
      await click(".save-changes");
      assert.dom(".saved").exists("it displays the saved message");
      find(".saved").remove();
    };

    await visit("/u/eviltrout/preferences/interface");

    // Live changes without reload
    const textSize = selectKit(".text-size .combo-box");
    await textSize.expand();
    await textSize.selectRowByValue("larger");
    assert.dom(document.documentElement).hasClass("text-size-larger");

    await textSize.expand();
    await textSize.selectRowByValue("largest");
    assert.dom(document.documentElement).hasClass("text-size-largest");

    assert.strictEqual(cookie("text_size"), undefined, "cookie is not set");

    // Click save (by default this sets for all browsers, no cookie)
    await savePreferences();

    assert.strictEqual(cookie("text_size"), undefined, "cookie is not set");

    await textSize.expand();
    await textSize.selectRowByValue("larger");
    await click(".text-size input[type=checkbox]");

    await savePreferences();

    assert.strictEqual(cookie("text_size"), "larger|1", "cookie is set");
    await click(".text-size input[type=checkbox]");
    await textSize.expand();
    await textSize.selectRowByValue("largest");

    await savePreferences();
    assert.strictEqual(cookie("text_size"), undefined, "cookie is removed");

    removeCookie("text_size");
  });

  skip("shows no default option for light scheme when theme's color scheme is user selectable", async function (assert) {
    let meta = document.createElement("meta");
    meta.name = "discourse_theme_id";
    meta.content = "2";
    document.getElementsByTagName("head")[0].appendChild(meta);

    let site = Site.current();
    site.set("user_themes", [
      { theme_id: 1, name: "Cool Theme", color_scheme_id: 2, default: true },
      {
        theme_id: 2,
        name: "Some Other Theme",
        color_scheme_id: 3,
        default: false,
      },
    ]);

    site.set("user_color_schemes", [
      { id: 2, name: "Cool Breeze" },
      { id: 3, name: "Dark Night" },
    ]);

    await visit("/u/eviltrout/preferences/interface");

    assert.dom(".light-color-scheme").exists("has regular dropdown");
    assert.strictEqual(selectKit(".theme .select-kit").header().value(), "2");

    await selectKit(".light-color-scheme .select-kit").expand();
    assert
      .dom(".light-color-scheme .select-kit .select-kit-row")
      .exists({ count: 2 });

    document.querySelector("meta[name='discourse_theme_id']").remove();
  });

  test("shows reset seen user tips popups button", async function (assert) {
    let site = Site.current();
    site.set("user_tips", { first_notification: 1 });

    await visit("/u/eviltrout/preferences/interface");

    assert
      .dom(".pref-reset-seen-user-tips")
      .exists("has reset seen user tips button");

    await click(".pref-reset-seen-user-tips");

    assert.deepEqual(lastUserData, {
      seen_popups: "",
      skip_new_user_tips: "false",
    });
  });
});

acceptance(
  "User Preferences Color Schemes (with default dark scheme)",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/color-scheme-stylesheet/2/2.json", () => {
        return helper.response({
          success: "OK",
        });
      });
      server.get("/color-scheme-stylesheet/3/2.json", () => {
        return helper.response({
          new_href: "3.css",
        });
      });
      server.get("/u/charlie.json", () => {
        return helper.response(userFixtures["/u/charlie.json"]);
      });
    });
    needs.hooks.beforeEach(() => {
      let meta = document.createElement("meta");
      meta.name = "discourse_theme_id";
      meta.content = "2";
      document.getElementsByTagName("head")[0].appendChild(meta);
    });

    test("no color scheme picker by default", async function (assert) {
      let site = Site.current();
      site.set("user_color_schemes", []);

      await visit("/u/eviltrout/preferences/interface");
      assert.dom(".control-group.color-scheme").doesNotExist();
    });

    test("light color scheme picker", async function (assert) {
      let site = Site.current();
      site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

      await visit("/u/eviltrout/preferences/interface");
      assert.dom(".light-color-scheme").exists("has regular picker dropdown");
      assert
        .dom(".dark-color-scheme")
        .doesNotExist("does not have a dark color scheme picker");
    });

    test("light color scheme defaults to custom scheme selected by user", async function (assert) {
      let site = Site.current();
      let session = Session.current();
      session.userColorSchemeId = 2;
      site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

      await visit("/u/eviltrout/preferences/interface");
      assert.dom(".light-color-scheme").exists("has light scheme dropdown");
      assert
        .dom(".light-color-scheme .selected-name")
        .hasAttribute(
          "data-value",
          session.userColorSchemeId.toString(),
          "user's selected color scheme is selected value in light scheme dropdown"
        );
    });

    test("always display 'Theme default'", async function (assert) {
      let meta = document.createElement("meta");
      meta.name = "discourse_theme_id";
      meta.content = "1";
      document.getElementsByTagName("head")[0].appendChild(meta);

      let session = Session.current();
      session.userColorSchemeId = -1;

      let site = Site.current();
      site.set("user_themes", [
        { theme_id: 1, name: "A Theme", color_scheme_id: 2, default: true },
      ]);

      site.set("user_color_schemes", [{ id: 3, name: "A Color Scheme" }]);

      await visit("/u/eviltrout/preferences/interface");

      assert.dom(".light-color-scheme").exists("has regular dropdown");
      const dropdownObject = selectKit(".light-color-scheme .select-kit");
      assert.strictEqual(dropdownObject.header().value(), "-1");
      assert.strictEqual(
        dropdownObject.header().label(),
        i18n("user.color_schemes.default_description")
      );

      await dropdownObject.expand();
      assert.strictEqual(dropdownObject.rows().length, 2);

      document.querySelector("meta[name='discourse_theme_id']").remove();
    });

    test("light and dark color scheme pickers", async function (assert) {
      let site = Site.current();
      let session = Session.current();
      session.userDarkSchemeId = 1; // same as default set in site settings

      site.set("default_dark_color_scheme", { id: 1, name: "Dark" });
      site.set("user_color_schemes", [
        { id: 2, name: "Cool Breeze" },
        { id: 3, name: "Dark Night", is_dark: true },
      ]);

      const savePreferences = async () => {
        assert.dom(".saved").doesNotExist("hasn't been saved yet");
        await click(".save-changes");
        assert.dom(".saved").exists("displays the saved message");
        find(".saved").remove();
      };

      await visit("/u/eviltrout/preferences/interface");

      // force light mode, otherwise mode is ambiguous
      const interfaceColor = this.container.lookup("service:interface-color");
      interfaceColor.forceLightMode();

      assert.dom(".light-color-scheme").exists("has regular dropdown");
      assert.dom(".dark-color-scheme").exists("has dark color scheme dropdown");
      assert
        .dom(".dark-color-scheme .selected-name")
        .hasAttribute(
          "data-value",
          session.userDarkSchemeId.toString(),
          "sets site default as selected dark scheme"
        );

      removeCookie("color_scheme_id");
      removeCookie("dark_scheme_id");

      await selectKit(".light-color-scheme .combobox").expand();
      await selectKit(".light-color-scheme .combobox").selectRowByValue(2);
      assert.strictEqual(
        cookie("color_scheme_id"),
        undefined,
        "cookie is not set"
      );
      assert.strictEqual(
        cookie("dark_scheme_id"),
        undefined,
        "cookie is not set"
      );
      assert
        .dom(".color-scheme-checkbox input:checked")
        .exists("defaults to storing values in user options");

      await savePreferences();
      assert.strictEqual(
        cookie("color_scheme_id"),
        undefined,
        "cookie is unchanged"
      );
      assert.strictEqual(
        cookie("dark_scheme_id"),
        undefined,
        "cookie is unchanged"
      );

      // Switch to saving changes in cookies
      await click(".color-scheme-checkbox input[type=checkbox]");
      await savePreferences();
      assert.strictEqual(cookie("color_scheme_id"), "2", "cookie is set");

      // dark scheme
      await selectKit(".dark-color-scheme .combobox").expand();
      assert.true(
        selectKit(".dark-color-scheme .combobox").rowByValue(3).exists(),
        "user selectable dark scheme is included"
      );

      await click("button.undo-preview");
      assert.strictEqual(
        selectKit(".light-color-scheme .combobox").header().value(),
        null,
        "resets light scheme dropdown"
      );

      assert.strictEqual(
        selectKit(".dark-color-scheme .combobox").header().value(),
        session.userDarkSchemeId.toString(),
        "resets dark scheme dropdown"
      );
    });

    skip("preview the color scheme only in current user's profile", async function (assert) {
      let site = Site.current();
      site.set("user_themes", [
        {
          theme_id: 2,
          name: "Cool Theme",
          color_scheme_id: 3,
          dark_color_scheme_id: 1,
        },
      ]);

      site.set("default_dark_color_scheme", { id: 1, name: "Dark" });
      site.set("user_color_schemes", [
        { id: 2, name: "Cool Breeze" },
        { id: 3, name: "Dark Night", is_dark: true },
      ]);

      await visit("/u/eviltrout/preferences/interface");

      await selectKit(".light-color-scheme .combobox").expand();
      await selectKit(".light-color-scheme .combobox").selectRowByValue(3);

      assert
        .dom("link#cs-preview-light", document.body)
        .hasAttribute("href", "3.css", "correct stylesheet loaded");

      document.querySelector("link#cs-preview-light").remove();

      await visit("/u/charlie/preferences/interface");

      await selectKit(".light-color-scheme .combobox").expand();
      await selectKit(".light-color-scheme .combobox").selectRowByValue(3);

      assert
        .dom("link#cs-preview-light", document.body)
        .doesNotExist("stylesheet not loaded");
    });
  }
);
