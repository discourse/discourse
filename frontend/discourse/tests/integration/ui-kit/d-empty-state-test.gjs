import { trustHTML } from "@ember/template";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEmptyState from "discourse/ui-kit/d-empty-state";

module("Integration | ui-kit | DEmptyState", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the root container with the text-only modifier by default", async function (assert) {
    await render(<template><DEmptyState @title="Nothing here" /></template>);
    assert.dom(".empty-state__container.--text-only").exists();
  });

  test("renders title and body", async function (assert) {
    await render(
      <template><DEmptyState @title="My title" @body="My body" /></template>
    );

    assert.dom("[data-test-title]").hasText("My title");
    assert.dom("[data-test-body]").hasText("My body");
  });

  test("@identifier is appended as a container modifier class", async function (assert) {
    await render(<template><DEmptyState @identifier="bookmarks" /></template>);
    assert.dom(".empty-state__container.--bookmarks").exists();
  });

  test("@svgContent renders the illustration and switches to --with-image", async function (assert) {
    const svg = trustHTML("<svg class='my-svg'></svg>");

    await render(
      <template><DEmptyState @title="x" @svgContent={{svg}} /></template>
    );

    assert.dom(".empty-state__container.--with-image").exists();
    assert.dom(".empty-state__image .my-svg").exists();
  });

  test("@ctaLabel renders a primary button that fires @ctaAction on click", async function (assert) {
    let called = false;
    this.set("ctaAction", () => {
      called = true;
    });

    await render(
      <template>
        <DEmptyState
          @ctaLabel="Add bookmark"
          @ctaIcon="plus"
          @ctaAction={{this.ctaAction}}
        />
      </template>
    );

    assert.dom(".empty-state__cta .btn.btn-primary").exists();
    assert.dom(".empty-state__cta .d-icon-plus").exists();
    assert.dom(".empty-state__cta .d-button-label").hasText("Add bookmark");

    await click(".empty-state__cta .btn");
    assert.true(called, "@ctaAction is fired on click");
  });

  test("@ctaHref renders the CTA as an anchor", async function (assert) {
    await render(
      <template>
        <DEmptyState
          @ctaLabel="Open docs"
          @ctaHref="https://example.com/docs"
        />
      </template>
    );

    assert
      .dom(".empty-state__cta a.btn")
      .hasAttribute("href", "https://example.com/docs");
  });

  test("@tipText renders inside the tip slot", async function (assert) {
    await render(<template><DEmptyState @tipText="Did you know?" /></template>);
    assert.dom(".empty-state__tip").hasText("Did you know?");
  });

  test("@tipIcon renders before the tip content", async function (assert) {
    await render(
      <template>
        <DEmptyState @tipText="Did you know?" @tipIcon="lightbulb" />
      </template>
    );
    assert.dom(".empty-state__tip .d-icon-lightbulb").exists();
  });

  test("the :tip named block takes precedence over @tipText", async function (assert) {
    await render(
      <template>
        <DEmptyState @tipText="Plain tip">
          <:tip>
            <span class="custom-tip">Block tip</span>
          </:tip>
        </DEmptyState>
      </template>
    );

    assert.dom(".empty-state__tip .custom-tip").hasText("Block tip");
    assert
      .dom(".empty-state__tip")
      .doesNotContainText("Plain tip", "the @tipText is suppressed");
  });

  test("the tip section is hidden when neither @tipText nor :tip block is provided", async function (assert) {
    await render(<template><DEmptyState @title="x" /></template>);
    assert.dom(".empty-state__tip").doesNotExist();
  });
});
