import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import Site from "discourse/models/site";
import Session from "discourse/models/session";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { click } from "@ember/test-helpers";

acceptance("User Preferences - Interface", function (needs) {
  needs.user();

  test("font size change", async (assert) => {
    removeCookie("text_size");

    const savePreferences = async () => {
      assert.ok(!exists(".saved"), "it hasn't been saved yet");
      await click(".save-changes");
      assert.ok(exists(".saved"), "it displays the saved message");
      find(".saved").remove();
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

  test("does not show option to disable dark mode by default", async (assert) => {
    await visit("/u/eviltrout/preferences/interface");
    assert.equal($(".control-group.dark-mode").length, 0);
  });

  test("shows light/dark color scheme pickers", async (assert) => {
    let site = Site.current();
    site.set("user_color_schemes", [
      { id: 2, name: "Cool Breeze" },
      { id: 3, name: "Dark Night", is_dark: true },
    ]);

    await visit("/u/eviltrout/preferences/interface");
    assert.ok($(".light-color-scheme").length, "has regular dropdown");
    assert.ok($(".dark-color-scheme").length, "has dark color scheme dropdown");
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

    test("show option to disable dark mode", async (assert) => {
      await visit("/u/eviltrout/preferences/interface");

      assert.ok(
        $(".control-group.dark-mode").length,
        "it has the option to disable dark mode"
      );
    });

    test("no color scheme picker by default", async (assert) => {
      let site = Site.current();
      site.set("user_color_schemes", []);

      await visit("/u/eviltrout/preferences/interface");
      assert.equal($(".control-group.color-scheme").length, 0);
    });

    test("light color scheme picker", async (assert) => {
      let site = Site.current();
      site.set("user_color_schemes", [{ id: 2, name: "Cool Breeze" }]);

      await visit("/u/eviltrout/preferences/interface");
      assert.ok($(".light-color-scheme").length, "has regular picker dropdown");
      assert.equal(
        $(".dark-color-scheme").length,
        0,
        "does not have a dark color scheme picker"
      );
    });

    test("light and dark color scheme pickers", async (assert) => {
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
        find(".saved").remove();
      };

      await visit("/u/eviltrout/preferences/interface");
      assert.ok($(".light-color-scheme").length, "has regular dropdown");
      assert.ok(
        $(".dark-color-scheme").length,
        "has dark color scheme dropdown"
      );
      assert.equal(
        $(".dark-color-scheme .selected-name").data("value"),
        session.userDarkSchemeId,
        "sets site default as selected dark scheme"
      );
      assert.equal(
        $(".control-group.dark-mode").length,
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
