import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import cookie, { removeCookie } from "discourse/lib/cookie";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

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
      query(".saved").remove();
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

  test("does not show option to disable dark mode by default", async function (assert) {
    await visit("/u/eviltrout/preferences/interface");
    assert.dom(".control-group.dark-mode").doesNotExist("option not visible");
  });

  test("shows light/dark color scheme pickers", async function (assert) {
    let site = Site.current();
    site.set("user_color_schemes", [
      { id: 2, name: "Cool Breeze" },
      { id: 3, name: "Dark Night", is_dark: true },
    ]);

    await visit("/u/eviltrout/preferences/interface");
    assert.dom(".light-color-scheme").exists("has regular dropdown");
    assert.dom(".dark-color-scheme").exists("has dark color scheme dropdown");
  });

  test("shows light color scheme default option when theme's color scheme is not user selectable", async function (assert) {
    let site = Site.current();
    site.set("user_themes", [
      { theme_id: 1, name: "Cool Theme", color_scheme_id: null },
    ]);

    site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

    await visit("/u/eviltrout/preferences/interface");
    assert.dom(".light-color-scheme").exists("has regular dropdown");

    assert.strictEqual(
      selectKit(".light-color-scheme .select-kit").header().value(),
      null
    );
    assert.strictEqual(
      selectKit(".light-color-scheme .select-kit").header().label(),
      I18n.t("user.color_schemes.default_description")
    );
  });

  test("shows no default option for light scheme when theme's color scheme is user selectable", async function (assert) {
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
    needs.settings({ default_dark_mode_color_scheme_id: 1 });
    needs.pretender((server, helper) => {
      server.get("/color-scheme-stylesheet/2.json", () => {
        return helper.response({
          success: "OK",
        });
      });
      server.get("/color-scheme-stylesheet/3.json", () => {
        return helper.response({
          new_href: "3.css",
        });
      });
      server.get("/u/charlie.json", () => {
        return helper.response(userFixtures["/u/charlie.json"]);
      });
    });

    test("show option to disable dark mode", async function (assert) {
      await visit("/u/eviltrout/preferences/interface");

      assert
        .dom(".control-group.dark-mode")
        .exists("has the option to disable dark mode");
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
      assert.strictEqual(
        query(".light-color-scheme .selected-name").dataset.value,
        session.userColorSchemeId.toString(),
        "user's selected color scheme is selected value in light scheme dropdown"
      );
    });

    test("display 'Theme default' when default color scheme is not marked as selectable", async function (assert) {
      let meta = document.createElement("meta");
      meta.name = "discourse_theme_id";
      meta.content = "1";
      document.getElementsByTagName("head")[0].appendChild(meta);

      let site = Site.current();
      site.set("user_themes", [
        { theme_id: 1, name: "A Theme", color_scheme_id: 2, default: true },
      ]);

      site.set("user_color_schemes", [{ id: 3, name: "A Color Scheme" }]);

      await visit("/u/eviltrout/preferences/interface");

      assert.dom(".light-color-scheme").exists("has regular dropdown");
      const dropdownObject = selectKit(".light-color-scheme .select-kit");
      assert.strictEqual(dropdownObject.header().value(), null);
      assert.strictEqual(
        dropdownObject.header().label(),
        I18n.t("user.color_schemes.default_description")
      );

      await dropdownObject.expand();
      assert.strictEqual(dropdownObject.rows().length, 1);

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
        query(".saved").remove();
      };

      await visit("/u/eviltrout/preferences/interface");
      assert.dom(".light-color-scheme").exists("has regular dropdown");
      assert.dom(".dark-color-scheme").exists("has dark color scheme dropdown");
      assert.strictEqual(
        query(".dark-color-scheme .selected-name").dataset.value,
        session.userDarkSchemeId.toString(),
        "sets site default as selected dark scheme"
      );
      assert
        .dom(".control-group.dark-mode")
        .doesNotExist("does not show disable dark mode checkbox");

      removeCookie("color_scheme_id");
      removeCookie("dark_scheme_id");

      await selectKit(".light-color-scheme .combobox").expand();
      await selectKit(".light-color-scheme .combobox").selectRowByValue(2);
      assert.strictEqual(
        cookie("color_scheme_id"),
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

      // Switch to saving changes in cookies
      await click(".color-scheme-checkbox input[type=checkbox]");
      await savePreferences();
      assert.strictEqual(cookie("color_scheme_id"), "2", "cookie is set");

      // dark scheme
      await selectKit(".dark-color-scheme .combobox").expand();
      assert.ok(
        selectKit(".dark-color-scheme .combobox").rowByValue(1).exists(),
        "default dark scheme is included"
      );

      await selectKit(".dark-color-scheme .combobox").selectRowByValue(-1);
      assert.strictEqual(
        cookie("dark_scheme_id"),
        undefined,
        "cookie is not set before saving"
      );

      await savePreferences();
      assert.strictEqual(cookie("dark_scheme_id"), "-1", "cookie is set");

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

    test("preview the color scheme only in current user's profile", async function (assert) {
      let site = Site.current();

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

      assert.notOk(
        document.querySelector("link#cs-preview-light"),
        "stylesheet not loaded"
      );
    });
  }
);
