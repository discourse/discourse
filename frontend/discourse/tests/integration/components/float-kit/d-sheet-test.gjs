import { tracked } from "@glimmer/tracking";
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
