import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Admin - Themes - Install modal", function (needs) {
  needs.user();
  test("closing the modal resets the modal inputs", async function (assert) {
    const urlInput = ".install-theme-content .repo input";
    const branchInput = ".install-theme-content .branch input";
    const privateRepoCheckbox = ".install-theme-content .check-private input";

    const themeUrl = "git@github.com:discourse/discourse.git";
    await visit("/admin/customize/themes");

    await click(".create-actions .btn-primary");
    await click("#remote");
    await fillIn(urlInput, themeUrl);
    await click(".install-theme-content .inputs .advanced-repo");
    await fillIn(branchInput, "tests-passed");
    await click(privateRepoCheckbox);
    assert.ok(queryAll(urlInput)[0].value === themeUrl, "url input is filled");
    assert.ok(
      queryAll(branchInput)[0].value === "tests-passed",
      "branch input is filled"
    );
    assert.ok(
      queryAll(privateRepoCheckbox)[0].checked,
      "private repo checkbox is checked"
    );

    await click(".modal-footer .d-modal-cancel");

    await click(".create-actions .btn-primary");
    await click("#remote");
    assert.ok(queryAll(urlInput)[0].value === "", "url input is reset");
    assert.ok(queryAll(branchInput)[0].value === "", "branch input is reset");
    assert.ok(
      !queryAll(privateRepoCheckbox)[0].checked,
      "private repo checkbox unchecked"
    );
  });

  test("modal can be auto-opened with the right query params", async function (assert) {
    await visit("/admin/customize/themes?repoUrl=testUrl&repoName=testName");
    assert.ok(queryAll(".admin-install-theme-modal"), "modal is visible");
    assert.ok(
      queryAll(".install-theme code").text().trim() === "testUrl",
      "repo url is visible"
    );
  });
});
