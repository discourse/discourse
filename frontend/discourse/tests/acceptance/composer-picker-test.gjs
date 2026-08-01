import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { registerComposerPickerTab } from "discourse/lib/composer-picker";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const StubPanel = <template>
  <div class="stub-picker-panel"></div>
</template>;

acceptance("Composer picker - upcoming change enabled", function (needs) {
  needs.user();
  needs.settings({
    enable_emoji: false,
    enable_gifs: false,
    enable_unified_composer_picker: true,
  });

  test("adds the toolbar button for a tab registered after boot", async function (assert) {
    await visit("/");

    // Registered after the app (and the composer-picker initializer) has
    // booted — the case a plugin initializer hits.
    registerComposerPickerTab({
      id: "test-picker-tab",
      icon: "star",
      title: "composer_picker.tabs.emoji",
      component: StubPanel,
      enabled: () => true,
    });

    await click("#create-topic");

    assert
      .dom(".insert-composer-emoji")
      .exists("the picker button is registered for the late-added tab");
  });
});

acceptance(
  "Composer picker - unified picker replaces the separate GIF button",
  function (needs) {
    needs.user();
    needs.settings({
      enable_emoji: true,
      enable_gifs: true,
      enable_unified_composer_picker: true,
    });

    test("shows the picker button and no standalone GIF button", async function (assert) {
      await visit("/");
      await click("#create-topic");

      assert.dom(".insert-composer-emoji").exists("the picker button is shown");
      assert
        .dom(".d-editor-button-bar button.gifs")
        .doesNotExist("GIFs are a picker tab, not a separate toolbar button");
    });
  }
);

acceptance(
  "Composer picker - legacy fallback when the upcoming change is off",
  function (needs) {
    needs.user();
    needs.settings({
      enable_emoji: true,
      enable_gifs: true,
      enable_unified_composer_picker: false,
    });

    test("shows the classic emoji button and the standalone GIF button", async function (assert) {
      await visit("/");
      await click("#create-topic");

      assert
        .dom(".insert-composer-emoji")
        .exists("the classic emoji button is shown");
      assert
        .dom(".d-editor-button-bar button.gifs")
        .exists("the standalone GIF button is shown");
    });
  }
);
