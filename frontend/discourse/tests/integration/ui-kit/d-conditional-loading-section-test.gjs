import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DConditionalLoadingSection", function (hooks) {
  setupRenderingTest(hooks);

  test("shows a default title while loading", async function (assert) {
    await render(
      <template>
        <DConditionalLoadingSection @isLoading={{true}}>
          <p class="content">content</p>
        </DConditionalLoadingSection>
      </template>
    );

    assert
      .dom(".conditional-loading-section")
      .hasClass("is-loading", "marks the section as loading");
    assert.dom(".title").hasText(i18n("conditional_loading_section.loading"));
    assert.dom(".content").doesNotExist("hides the content");
  });

  test("shows a given title while loading", async function (assert) {
    await render(
      <template>
        <DConditionalLoadingSection @isLoading={{true}} @title="Saving" />
      </template>
    );

    assert.dom(".title").hasText("Saving");
  });

  test("renders the content once loaded", async function (assert) {
    await render(
      <template>
        <DConditionalLoadingSection @isLoading={{false}}>
          <p class="content">content</p>
        </DConditionalLoadingSection>
      </template>
    );

    assert.dom(".content").exists();
    assert.dom(".title").doesNotExist();
  });
});
