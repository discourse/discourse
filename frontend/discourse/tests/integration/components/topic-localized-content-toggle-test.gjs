import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicLocalizedContentToggle from "discourse/components/topic-localized-content-toggle";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | topic-localized-content-toggle",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    hooks.beforeEach(function () {
      const router = this.owner.lookup("service:router");
      router.currentURL = "/t/1";
      router.refresh = async () => {};
      router.replaceWith = () => {};
    });

    const TOGGLE_SELECTOR = "button.btn-toggle-localized-content";

    test("updates tooltip after toggling from translated to original", async function (assert) {
      this.currentUser.user_option.show_original_content = false;

      pretender.put("/u/eviltrout.json", () => response({}));

      const topic = { postStream: { removeAllPosts() {} } };

      await render(
        <template><TopicLocalizedContentToggle @topic={{topic}} /></template>
      );

      assert
        .dom(TOGGLE_SELECTOR)
        .hasAttribute(
          "title",
          i18n("content_localization.toggle_localized.translated"),
          "shows translated tooltip when viewing translated content"
        );

      assert
        .dom(TOGGLE_SELECTOR)
        .hasClass(
          "--active",
          "button is active when showing translated content"
        );

      await click(TOGGLE_SELECTOR);

      assert
        .dom(TOGGLE_SELECTOR)
        .hasAttribute(
          "title",
          i18n("content_localization.toggle_localized.not_translated"),
          "shows not_translated tooltip after toggling to original"
        );

      assert
        .dom(TOGGLE_SELECTOR)
        .doesNotHaveClass(
          "--active",
          "button is not active when showing original content"
        );
    });

    test("updates tooltip after toggling from original to translated", async function (assert) {
      this.currentUser.user_option.show_original_content = true;

      pretender.put("/u/eviltrout.json", () => response({}));

      const topic = { postStream: { removeAllPosts() {} } };

      await render(
        <template><TopicLocalizedContentToggle @topic={{topic}} /></template>
      );

      assert
        .dom(TOGGLE_SELECTOR)
        .hasAttribute(
          "title",
          i18n("content_localization.toggle_localized.not_translated"),
          "shows not_translated tooltip when viewing original content"
        );

      assert
        .dom(TOGGLE_SELECTOR)
        .doesNotHaveClass(
          "--active",
          "button is not active when showing original content"
        );

      await click(TOGGLE_SELECTOR);

      assert
        .dom(TOGGLE_SELECTOR)
        .hasAttribute(
          "title",
          i18n("content_localization.toggle_localized.translated"),
          "shows translated tooltip after toggling to translated"
        );

      assert
        .dom(TOGGLE_SELECTOR)
        .hasClass(
          "--active",
          "button is active when showing translated content"
        );
    });
  }
);
