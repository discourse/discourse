import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Themes - Install modal", function (needs) {
  needs.user();

  test("closing the modal resets the modal inputs", async function (assert) {
    const urlInput = ".install-theme-content .repo input";
    const branchInput = ".install-theme-content .branch input";
    const publicKey = ".install-theme-content .public-key textarea";

    const themeUrl = "git@github.com:discourse/discourse.git";
    await visit("/admin/customize/themes");

    await click(".create-actions .btn-primary");
    await click("#remote");
    await fillIn(urlInput, themeUrl);
    await click(".install-theme-content .inputs .advanced-repo");
    await fillIn(branchInput, "tests-passed");
    assert.dom(urlInput).hasValue(themeUrl, "url input is filled");
    assert.dom(branchInput).hasValue("tests-passed", "branch input is filled");
    assert.dom(publicKey).exists("shows public key");

    await click(".d-modal__footer .d-modal-cancel");

    await click(".create-actions .btn-primary");
    await click("#remote");
    await click(".install-theme-content .inputs .advanced-repo");
    assert.dom(urlInput).hasValue("", "url input is reset");
    assert.dom(branchInput).hasValue("", "branch input is reset");
    assert.dom(publicKey).doesNotExist("hide public key");
  });

  test("show public key for valid ssh theme urls", async function (assert) {
    const urlInput = ".install-theme-content .repo input";
    const publicKey = ".install-theme-content .public-key textarea";

    // Supports backlog repo ssh url format
    const themeUrl =
      "discourse@discourse.git.backlog.com:/TEST_THEME/test-theme.git";
    await visit("/admin/customize/themes");

    await click(".create-actions .btn-primary");
    await click("#remote");
    await fillIn(urlInput, themeUrl);
    await click(".install-theme-content .inputs .advanced-repo");
    assert.dom(urlInput).hasValue(themeUrl, "url input is filled");
    assert.dom(publicKey).exists("shows public key");

    // Supports AWS CodeCommit style repo URLs
    await fillIn(
      urlInput,
      "ssh://someID@git-codecommit.us-west-2.amazonaws.com/v1/repos/test-repo.git"
    );
    assert.dom(publicKey).exists("shows public key");

    await fillIn(urlInput, "https://github.com/discourse/discourse.git");
    assert
      .dom(publicKey)
      .doesNotExist("does not show public key for https urls");

    await fillIn(urlInput, "git@github.com:discourse/discourse.git");
    assert.dom(publicKey).exists("shows public key for valid github repo url");

    await fillIn(urlInput, "git@github.com:discourse/discourse");
    assert.dom(publicKey).exists("shows public key for valid github repo url");

    await fillIn(urlInput, "git@github.com/discourse/discourse");
    assert
      .dom(publicKey)
      .doesNotExist("does not shows public key for valid github repo url");
  });

  test("modal can be auto-opened with the right query params", async function (assert) {
    await visit("/admin/customize/themes?repoUrl=testUrl&repoName=testName");
    assert.dom(".admin-install-theme-modal").exists("modal is visible");
    assert.dom(".install-theme code").hasText("testUrl", "repo url is visible");

    await click(".d-modal-cancel");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/themes",
      "query params are cleared after dismissing the modal"
    );
  });

  test("installed themes are matched with the popular list by URL", async function (assert) {
    await visit("/admin/customize/themes");
    await click(".create-actions .btn-primary");

    assert
      .dom(
        '.popular-theme-item[data-name="Graceful"] .popular-theme-buttons button'
      )
      .doesNotExist("no install button is shown for installed themes");
    assert
      .dom('.popular-theme-item[data-name="Graceful"] .popular-theme-buttons')
      .hasText(i18n("admin.customize.theme.installed"));

    assert
      .dom(
        '.popular-theme-item[data-name="Mint"] .popular-theme-buttons button'
      )
      .exists("install button is shown for not installed themes");
  });
});
