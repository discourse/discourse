import {
  acceptance,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import cookie, { removeCookie } from "discourse/lib/cookie";
import I18n from "I18n";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("User Preferences - Interface", function (needs) {
  needs.user();

  test("font size change", async function (assert) {
    removeCookie("text_size");

    const savePreferences = async () => {
      assert.ok(!exists(".saved"), "it hasn't been saved yet");
      await click(".save-changes");
      assert.ok(exists(".saved"), "it displays the saved message");
      queryAll(".saved").remove();
    };

    await visit("/u/eviltrout/preferences/interface");

    // Live changes without reload
    await selectKit(".text-size .combobox").expand();
    await selectKit(".text-size .combobox").selectRowByValue("larger");
    assert.ok(document.documentElement.classList.contains("text-size-larger"));

    await selectKit(".text-size .combobox").expand();
    await selectKit(".text-size .combobox").selectRowByValue("largest");
    assert.ok(document.documentElement.classList.contains("text-size-largest"));

    assert.equal(cookie("text_size"), null, "cookie is not set");

    // Click save (by default this sets for all browsers, no cookie)
    await savePreferences();

    assert.equal(cookie("text_size"), null, "cookie is not set");

    await selectKit(".text-size .combobox").expand();
    await selectKit(".text-size .combobox").selectRowByValue("larger");
    await click(".text-size input[type=checkbox]");

    await savePreferences();

    assert.equal(cookie("text_size"), "larger|1", "cookie is set");
    await click(".text-size input[type=checkbox]");
    await selectKit(".text-size .combobox").expand();
    await selectKit(".text-size .combobox").selectRowByValue("largest");

    await savePreferences();
    assert.equal(cookie("text_size"), null, "cookie is removed");

    removeCookie("text_size");
  });

  test("does not show option to disable dark mode by default", async function (assert) {
    await visit("/u/eviltrout/preferences/interface");
    assert.ok(!exists(".control-group.dark-mode"), "option not visible");
  });

  test("shows light/dark color scheme pickers", async function (assert) {
    let site = Site.current();
    site.set("user_color_schemes", [
      { id: 2, name: "Cool Breeze" },
      { id: 3, name: "Dark Night", is_dark: true },
    ]);

    await visit("/u/eviltrout/preferences/interface");
    assert.ok(exists(".light-color-scheme"), "has regular dropdown");
    assert.ok(exists(".dark-color-scheme"), "has dark color scheme dropdown");
  });

  test("shows light color scheme default option when theme's color scheme is not user selectable", async function (assert) {
    let site = Site.current();
    site.set("user_themes", [
      { theme_id: 1, name: "Cool Theme", color_scheme_id: null },
    ]);

    site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

    await visit("/u/eviltrout/preferences/interface");
    assert.ok(exists(".light-color-scheme"), "has regular dropdown");

    assert.equal(
      selectKit(".light-color-scheme .select-kit").header().value(),
      null
    );
    assert.equal(
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

    assert.ok(exists(".light-color-scheme"), "has regular dropdown");
    assert.equal(selectKit(".theme .select-kit").header().value(), 2);

    await selectKit(".light-color-scheme .select-kit").expand();
    assert.equal(count(".light-color-scheme .select-kit .select-kit-row"), 2);

    document.querySelector("meta[name='discourse_theme_id']").remove();
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
    });

    test("show option to disable dark mode", async function (assert) {
      await visit("/u/eviltrout/preferences/interface");

      assert.ok(
        exists(".control-group.dark-mode"),
        "it has the option to disable dark mode"
      );
    });

    test("no color scheme picker by default", async function (assert) {
      let site = Site.current();
      site.set("user_color_schemes", []);

      await visit("/u/eviltrout/preferences/interface");
      assert.ok(!exists(".control-group.color-scheme"));
    });

    test("light color scheme picker", async function (assert) {
      let site = Site.current();
      site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

      await visit("/u/eviltrout/preferences/interface");
      assert.ok(exists(".light-color-scheme"), "has regular picker dropdown");
      assert.ok(
        !exists(".dark-color-scheme"),
        "does not have a dark color scheme picker"
      );
    });

    test("light color scheme defaults to custom scheme selected by user", async function (assert) {
      let site = Site.current();
      let session = Session.current();
      session.userColorSchemeId = 2;
      site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

      await visit("/u/eviltrout/preferences/interface");
      assert.ok(exists(".light-color-scheme"), "has light scheme dropdown");
      assert.equal(
        queryAll(".light-color-scheme .selected-name").data("value"),
        session.userColorSchemeId,
        "user's selected color scheme is selected value in light scheme dropdown"
      );
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
        assert.ok(!exists(".saved"), "it hasn't been saved yet");
        await click(".save-changes");
        assert.ok(exists(".saved"), "it displays the saved message");
        queryAll(".saved").remove();
      };

      await visit("/u/eviltrout/preferences/interface");
      assert.ok(exists(".light-color-scheme"), "has regular dropdown");
      assert.ok(exists(".dark-color-scheme"), "has dark color scheme dropdown");
      assert.equal(
        queryAll(".dark-color-scheme .selected-name").data("value"),
        session.userDarkSchemeId,
        "sets site default as selected dark scheme"
      );
      assert.ok(
        !exists(".control-group.dark-mode"),
        0,
        "it does not show disable dark mode checkbox"
      );

      removeCookie("color_scheme_id");
      removeCookie("dark_scheme_id");

      await selectKit(".light-color-scheme .combobox").expand();
      await selectKit(".light-color-scheme .combobox").selectRowByValue(2);
      assert.equal(cookie("color_scheme_id"), null, "cookie is not set");
      assert.ok(
        exists(".color-scheme-checkbox input:checked"),
        "defaults to storing values in user options"
      );

      await savePreferences();
      assert.equal(cookie("color_scheme_id"), null, "cookie is unchanged");

      // Switch to saving changes in cookies
      await click(".color-scheme-checkbox input[type=checkbox]");
      await savePreferences();
      assert.equal(cookie("color_scheme_id"), 2, "cookie is set");

      // dark scheme
      await selectKit(".dark-color-scheme .combobox").expand();
      assert.ok(
        selectKit(".dark-color-scheme .combobox").rowByValue(1).exists(),
        "default dark scheme is included"
      );

      await selectKit(".dark-color-scheme .combobox").selectRowByValue(-1);
      assert.equal(
        cookie("dark_scheme_id"),
        null,
        "cookie is not set before saving"
      );

      await savePreferences();
      assert.equal(cookie("dark_scheme_id"), -1, "cookie is set");

      await click("button.undo-preview");
      assert.equal(
        selectKit(".light-color-scheme .combobox").header().value(),
        null,
        "resets light scheme dropdown"
      );

      assert.equal(
        selectKit(".dark-color-scheme .combobox").header().value(),
        session.userDarkSchemeId,
        "resets dark scheme dropdown"
      );
    });
  }
);
