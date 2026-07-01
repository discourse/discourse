import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { click, find, render, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-sheet", function (hooks) {
  setupRenderingTest(hooks);

  test("exports title and description components", async function (assert) {
    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <DSheet.Title @sheet={{sheet}}>Sheet title</DSheet.Title>
                  <DSheet.Description @sheet={{sheet}}>
                    Sheet description
                  </DSheet.Description>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']");

    const view = find("[data-d-sheet~='view']");
    const titleId = view.getAttribute("aria-labelledby");
    const descriptionId = view.getAttribute("aria-describedby");

    assert
      .dom(`#${CSS.escape(titleId)}`)
      .hasText("Sheet title", "the namespace exports DSheet.Title");
    assert
      .dom(`#${CSS.escape(descriptionId)}`)
      .hasText("Sheet description", "the namespace exports DSheet.Description");
  });

  test("omits title and description references when they are not rendered", async function (assert) {
    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <p>Content</p>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor("[data-d-sheet~='view']");

    assert
      .dom("[data-d-sheet~='view']")
      .doesNotHaveAttribute(
        "aria-labelledby",
        "the view does not point at a missing title"
      );
    assert
      .dom("[data-d-sheet~='view']")
      .doesNotHaveAttribute(
        "aria-describedby",
        "the view does not point at a missing description"
      );
  });

  test("updates a controlled active detent while open", async function (assert) {
    const state = new (class {
      @tracked activeDetent = 1;
    })();
    const detents = ["30vh", "60vh"];
    const changes = [];

    const setSecondDetent = () => {
      state.activeDetent = 2;
    };

    const onActiveDetentChange = (detent) => {
      changes.push(detent);
    };

    await render(
      <template>
        <DSheet.Root
          @activeDetent={{state.activeDetent}}
          @onActiveDetentChange={{onActiveDetentChange}}
          as |sheet|
        >
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}} @detents={{detents}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <button
                    type="button"
                    class="set-second-detent"
                    {{on "click" setSecondDetent}}
                  >
                    Expand
                  </button>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    await click(".set-second-detent");
    await waitUntil(() => changes.includes(2), { timeout: 3000 });

    assert.true(
      changes.includes(2),
      "the controlled active detent change steps the open sheet"
    );
  });

  test("registered automatic layers do not dismiss the sheet", async function (assert) {
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const registerLayer = sheetLayerStore.registerAutomaticLayerElement;
    const unregisterLayer = sheetLayerStore.unregisterAutomaticLayerElement;

    await render(
      <template>
        <div
          class="external-layer"
          {{didInsert registerLayer}}
          {{willDestroy unregisterLayer}}
        >
          <button type="button" class="external-layer-button">Layer</button>
        </div>

        <DSheet.Root as |sheet|>
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <p>Content</p>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    await click(".external-layer-button");

    assert
      .dom("[data-d-sheet~='view']")
      .exists("clicks in registered external layers are ignored");
  });

  test("header close button dismisses the sheet", async function (assert) {
    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <DSheet.Header @sheet={{sheet}}>
                    <:left as |Button|>
                      <Button.Close class="header-close" />
                    </:left>
                    <:title>Sheet title</:title>
                  </DSheet.Header>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    assert.dom("[data-d-sheet~='view']").exists("the sheet opens");

    await click(".header-close");
    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 3000 });

    assert.dom("[data-d-sheet~='view']").doesNotExist("the sheet closes");
  });

  test("header close button updates a controlled root", async function (assert) {
    const state = new (class {
      @tracked presented = false;
    })();
    const changes = [];

    const onPresentedChange = (value) => {
      changes.push(value);
      state.presented = value;
    };

    await render(
      <template>
        <DSheet.Root
          @presented={{state.presented}}
          @onPresentedChange={{onPresentedChange}}
          as |sheet|
        >
          <DSheet.Trigger @sheet={{sheet}}>Open</DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <DSheet.Header @sheet={{sheet}}>
                    <:left as |Button|>
                      <Button.Close class="header-close" />
                    </:left>
                    <:title>Sheet title</:title>
                  </DSheet.Header>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".btn");
    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    assert.true(state.presented, "the controlled root opens");

    await click(".header-close");
    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 3000 });

    assert.false(state.presented, "the controlled root is dismissed");
    assert.deepEqual(
      changes,
      [true, false],
      "header close emits a single close change"
    );
  });
});
