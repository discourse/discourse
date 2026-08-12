import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import {
  click,
  find,
  render,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-sheet", function (hooks) {
  setupRenderingTest(hooks);

  test("an opened sheet remains presented after travel settles", async function (assert) {
    const OriginalResizeObserver = window.ResizeObserver;
    let sheetController;
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };

    window.ResizeObserver = class {
      observe() {}
      unobserve() {}
      disconnect() {}
    };

    try {
      await render(
        <template>
          <DSheet.Root @defaultPresented={{true}} as |sheet|>
            <div hidden {{didInsert captureSheet sheet}}></div>
            <DSheet.Portal @sheet={{sheet}}>
              <DSheet.View @sheet={{sheet}}>
                <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                  <ContentTag>Content</ContentTag>
                </DSheet.Content>
              </DSheet.View>
            </DSheet.Portal>
          </DSheet.Root>
        </template>
      );

      await waitUntil(() => sheetController?.state.openness.isOpen, {
        timeout: 3000,
      });
      await new Promise((resolve) => setTimeout(resolve, 100));

      assert.true(
        sheetController.dimensions.view.travelAxis.unitless > 1,
        "the first measurement uses the presented view geometry"
      );
      assert.true(
        sheetController.state.openness.isOpen,
        "the settled travel does not trigger a spurious swipe-out"
      );
      assert.dom("[data-d-sheet~='view']").exists();

      const view = find("[data-d-sheet~='view']");
      const viewRect = view.getBoundingClientRect();
      const contentRect = find(
        "[data-d-sheet~='content']"
      ).getBoundingClientRect();
      const contentIntersectsView =
        contentRect.bottom > viewRect.top && contentRect.top < viewRect.bottom;
      assert.true(
        contentIntersectsView,
        `the settled content intersects its view (${JSON.stringify({
          content: contentRect.toJSON(),
          view: viewRect.toJSON(),
        })})`
      );
      assert.false(
        view.dataset.dSheet.split(" ").includes("hidden"),
        "the settled view no longer has the staging visibility token"
      );
      assert.notStrictEqual(
        getComputedStyle(view).opacity,
        "0",
        "the settled view remains visible"
      );
    } finally {
      window.ResizeObserver = OriginalResizeObserver;
    }
  });

  test("opening rerenders do not hide an active travel", async function (assert) {
    const state = new (class {
      @tracked renderCount = 0;
    })();
    const hiddenSamples = [];
    let sheetController;
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const onTravel = () => {
      const view = find("[data-d-sheet~='view']");
      hiddenSamples.push(view?.dataset.dSheet.split(" ").includes("hidden"));

      if (state.renderCount < 8) {
        state.renderCount++;
      }
    };

    await render(
      <template>
        <DSheet.Root @defaultPresented={{true}} as |sheet|>
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View
              @sheet={{sheet}}
              @onTravel={{onTravel}}
              data-render-count={{state.renderCount}}
            >
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>Content</ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitUntil(() => sheetController?.state.openness.isOpen, {
      timeout: 3000,
    });

    assert.true(hiddenSamples.length > 1, "travel crossed multiple frames");
    assert.false(
      hiddenSamples.some(Boolean),
      "rerenders never restore the pre-travel hidden token"
    );
    assert.strictEqual(
      find("[data-d-sheet~='view']").dataset.renderCount,
      "8",
      "the view rerendered repeatedly during travel"
    );
  });

  test("a dismiss click during an opening rerender does not interrupt opening", async function (assert) {
    const state = new (class {
      @tracked renderCount = 0;
    })();
    const frameSamples = [];
    let sheetController;
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const onTravel = () => {
      const view = find("[data-d-sheet~='view']");
      frameSamples.push({
        hidden: view?.dataset.dSheet.split(" ").includes("hidden"),
      });

      if (state.renderCount < 8) {
        state.renderCount++;
      }
    };

    await render(
      <template>
        <DSheet.Root @defaultPresented={{true}} as |sheet|>
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View
              @sheet={{sheet}}
              @onTravel={{onTravel}}
              data-render-count={{state.renderCount}}
            >
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <DSheet.Trigger
                    @sheet={{sheet}}
                    @action="dismiss"
                    class="dismiss-during-opening"
                  >
                    Close
                  </DSheet.Trigger>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitUntil(() => frameSamples.length >= 3, { timeout: 3000 });
    assert.true(
      sheetController.state.openness.isOpening,
      "the click occurs while the opening travel is active"
    );

    await click(".dismiss-during-opening");
    await waitUntil(() => sheetController.state.openness.isOpen, {
      timeout: 3000,
    });

    assert.false(
      frameSamples.some(({ hidden }) => hidden),
      "opening rerenders remain visible throughout the request"
    );
    assert.false(
      sheetController.rootComponent.effectivePresented,
      "the dismiss click updates presentation"
    );
    assert.true(
      sheetController.state.openness.isOpen,
      "the opening completion still resolves to open"
    );
  });

  test("a resize correction completes before closing travel", async function (assert) {
    const OriginalResizeObserver = window.ResizeObserver;
    const resizeObserverCallbacks = new Map();
    let sheetController;
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };

    window.ResizeObserver = class {
      constructor(callback) {
        this.callback = callback;
      }

      observe(element) {
        resizeObserverCallbacks.set(element, this.callback);
      }

      unobserve(element) {
        if (resizeObserverCallbacks.get(element) === this.callback) {
          resizeObserverCallbacks.delete(element);
        }
      }

      disconnect() {
        for (const [element, callback] of resizeObserverCallbacks) {
          if (callback === this.callback) {
            resizeObserverCallbacks.delete(element);
          }
        }
      }
    };

    try {
      await render(
        <template>
          <DSheet.Root @defaultPresented={{true}} as |sheet|>
            <div hidden {{didInsert captureSheet sheet}}></div>
            <DSheet.Portal @sheet={{sheet}}>
              <DSheet.View @sheet={{sheet}} @swipe={{false}}>
                <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                  <ContentTag>
                    <DSheet.Trigger
                      @sheet={{sheet}}
                      @action="dismiss"
                      class="resize-race-close"
                    >
                      Close
                    </DSheet.Trigger>
                  </ContentTag>
                </DSheet.Content>
              </DSheet.View>
            </DSheet.Portal>
          </DSheet.Root>
        </template>
      );

      await waitUntil(() => sheetController?.state.openness.isOpen, {
        timeout: 3000,
      });

      let staleResizeTravelCount = 0;
      const recalculateAndTravel =
        sheetController.animationTravel.recalculateAndTravel.bind(
          sheetController.animationTravel
        );
      sheetController.animationTravel.recalculateAndTravel = (...args) => {
        staleResizeTravelCount++;
        return recalculateAndTravel(...args);
      };

      resizeObserverCallbacks.get(sheetController.content)([
        { target: sheetController.content },
      ]);

      assert.strictEqual(
        staleResizeTravelCount,
        0,
        "the initial content observation only refreshes geometry"
      );

      resizeObserverCallbacks.get(sheetController.content)([
        { target: sheetController.content },
      ]);

      assert.strictEqual(
        staleResizeTravelCount,
        1,
        "the synchronous resize correction runs before the exit travel"
      );

      find(".resize-race-close").click();

      await waitUntil(() => sheetController.state.openness.isClosedPending, {
        timeout: 3000,
      });

      assert.true(
        sheetController.state.openness.isClosedPending,
        "the exit travel reaches the pending closed state"
      );
    } finally {
      window.ResizeObserver = OriginalResizeObserver;
    }
  });

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

    await settled();
    changes.length = 0;
    await click(".set-second-detent");
    await waitUntil(() => changes.includes(2), { timeout: 3000 });

    assert.deepEqual(
      changes,
      [2],
      "the controlled active detent change is reported once"
    );
  });

  test("uses the latest default active detent on first presentation", async function (assert) {
    const state = new (class {
      @tracked defaultActiveDetent = 1;
    })();
    const detents = ["30vh"];
    let sheetController;

    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const updateDefaultActiveDetent = () => {
      state.defaultActiveDetent = 2;
    };

    await render(
      <template>
        <DSheet.Root
          @defaultActiveDetent={{state.defaultActiveDetent}}
          as |sheet|
        >
          <div hidden {{didInsert captureSheet sheet}}></div>
          <button
            type="button"
            class="update-default-active-detent"
            {{on "click" updateDefaultActiveDetent}}
          >
            Update default detent
          </button>
          <DSheet.Trigger @sheet={{sheet}} class="open-updated-default-sheet">
            Open
          </DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}} @detents={{detents}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>Content</ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await click(".update-default-active-detent");

    assert.strictEqual(
      sheetController.targetDetent,
      2,
      "the closed Controller receives the updated opening detent"
    );

    await click(".open-updated-default-sheet");
    await waitUntil(
      () =>
        sheetController.state.openness.isOpen &&
        sheetController.activeDetent === 2,
      { timeout: 3000 }
    );

    assert.strictEqual(
      sheetController.activeDetent,
      2,
      "the first presentation settles at the latest default detent"
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

  test("controlled swipe-out reports dismissed presentation", async function (assert) {
    let sheetController;
    const presentedChanges = [];
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const onPresentedChange = (presented) => {
      presentedChanges.push(presented);
    };

    await render(
      <template>
        <DSheet.Root
          @presented={{true}}
          @onPresentedChange={{onPresentedChange}}
          as |sheet|
        >
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}} @swipe={{false}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <button type="button">Content</button>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitUntil(() => sheetController?.state.openness.isOpen, {
      timeout: 3000,
    });

    sheetController.handleSwipeOut();

    assert.deepEqual(
      presentedChanges,
      [false],
      "reaching closed through swipe-out updates the controlled Root"
    );
  });

  test("an inert sheet excludes its Root content from interaction", async function (assert) {
    await render(
      <template>
        <DSheet.Root @defaultPresented={{true}} as |sheet|>
          <DSheet.Trigger @sheet={{sheet}} class="background-trigger">
            Open
          </DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <button type="button" class="sheet-focus-target">
                    Content
                  </button>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );
    await settled();

    const trigger = find(".background-trigger");
    assert.true(
      Boolean(trigger.closest("[inert]")),
      "the non-portaled Root content is outside the inert boundary"
    );

    trigger.focus();

    assert
      .dom(".sheet-focus-target")
      .isFocused("the inert trigger cannot take focus from the sheet");
  });

  test("focus containment restores focus and cycles through allowed roots", async function (assert) {
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const registerLayer = sheetLayerStore.registerAutomaticLayerElement;
    const unregisterLayer = sheetLayerStore.unregisterAutomaticLayerElement;
    const originalBodyTabIndex = document.body.getAttribute("tabindex");

    try {
      await render(
        <template>
          <div
            class="allowed-layer"
            {{didInsert registerLayer}}
            {{willDestroy unregisterLayer}}
          >
            <button type="button" class="allowed-layer-button">Layer</button>
          </div>

          <DSheet.Root @defaultPresented={{true}} as |sheet|>
            <DSheet.Portal @sheet={{sheet}}>
              <DSheet.View @sheet={{sheet}}>
                <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                  <ContentTag>
                    <button type="button" class="contained-button">
                      Content
                    </button>
                  </ContentTag>
                </DSheet.Content>
              </DSheet.View>
            </DSheet.Portal>
          </DSheet.Root>
        </template>
      );

      await waitFor(
        "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
      );
      await waitFor("[data-d-sheet~='focus-guard']");
      await settled();

      document.body.tabIndex = -1;
      document.body.focus();

      assert
        .dom(".contained-button")
        .isFocused("programmatic focus outside returns to the sheet");

      const view = find("[data-d-sheet~='view']");
      view.nextElementSibling.focus();

      assert
        .dom(".allowed-layer-button")
        .isFocused("Tab past the sheet enters the allowed layer");

      find(".allowed-layer").previousElementSibling.focus();

      assert
        .dom(".contained-button")
        .isFocused("Shift+Tab before the allowed layer returns to the sheet");
    } finally {
      if (originalBodyTabIndex === null) {
        document.body.removeAttribute("tabindex");
      } else {
        document.body.setAttribute("tabindex", originalBodyTabIndex);
      }
    }
  });

  test("remaps to the closest detent when detents change", async function (assert) {
    const state = new (class {
      @tracked detents = ["30vh"];
    })();
    let sheetController;

    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const updateDetents = () => {
      state.detents = undefined;
    };

    await render(
      <template>
        <DSheet.Root
          @defaultActiveDetent={{2}}
          @defaultPresented={{true}}
          as |sheet|
        >
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}} @detents={{state.detents}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <button
                    type="button"
                    class="update-detents"
                    {{on "click" updateDetents}}
                  >
                    Update detents
                  </button>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])",
      { timeout: 3000 }
    );
    await waitUntil(() => sheetController.activeDetent === 2, {
      timeout: 3000,
    });

    const initialDimensions = sheetController.dimensions;
    await click(".update-detents");
    await waitUntil(
      () =>
        sheetController.dimensions !== initialDimensions &&
        sheetController.dimensions?.detentMarkers.length === 1,
      { timeout: 3000 }
    );

    assert
      .dom("[data-d-sheet~='detent-marker']")
      .exists({ count: 1 }, "obsolete detent markers are removed");
    assert.strictEqual(
      sheetController.dimensions.detentMarkers.length,
      1,
      "dimensions are rebuilt from the updated detents"
    );
    assert.strictEqual(
      sheetController.activeDetent,
      1,
      "the removed active detent maps to the closest remaining detent"
    );
    assert.deepEqual(
      sheetController.currentSegment,
      [1, 1],
      "the resting segment follows the remapped detent"
    );
  });

  test("keeps the open lifecycle active and reopens during the pending window", async function (assert) {
    let sheetController;
    const detentChanges = [];

    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };
    const onActiveDetentChange = (detent) => {
      detentChanges.push(detent);
    };

    await render(
      <template>
        <DSheet.Root @onActiveDetentChange={{onActiveDetentChange}} as |sheet|>
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Trigger @sheet={{sheet}} class="open-sheet">
            Open
          </DSheet.Trigger>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View @sheet={{sheet}}>
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <DSheet.Trigger
                    @sheet={{sheet}}
                    @action="dismiss"
                    class="close-sheet"
                  >
                    Close
                  </DSheet.Trigger>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    const initialController = sheetController;
    await click(".open-sheet");
    await waitUntil(() => sheetController.state.openness.isOpen, {
      timeout: 3000,
    });
    await waitUntil(() => detentChanges.includes(1), { timeout: 3000 });
    detentChanges.length = 0;

    assert.true(
      sheetController.state.longRunning.isActive,
      "the long-running lifecycle remains active while the sheet is open"
    );

    await click(".close-sheet");
    await waitUntil(() => sheetController.state.openness.isClosedPending, {
      timeout: 3000,
    });
    assert.deepEqual(
      detentChanges,
      [0, 0],
      "accepted dismissal and closing travel match Silk callback timing"
    );

    assert.false(
      sheetController.state.longRunning.isActive,
      "the long-running lifecycle ends once the sheet is closed"
    );
    assert.false(
      sheetController.safeToUnmount,
      "the sheet stays mounted during the pending window"
    );
    assert
      .dom("[data-d-sheet~='view']")
      .exists("the view remains mounted during the pending window");
    assert.strictEqual(
      find(".open-sheet").closest("[inert]"),
      null,
      "the trigger is interactive during the pending window"
    );

    await click(".open-sheet");
    await waitUntil(() => sheetController.state.openness.isOpen, {
      timeout: 3000,
    });

    assert.strictEqual(
      sheetController,
      initialController,
      "a rapid reopen reuses the pending controller"
    );
    assert.notStrictEqual(
      find(".open-sheet").closest("[inert]"),
      null,
      "the reopened sheet restores its interaction layer"
    );
    assert
      .dom("[data-d-sheet~='view']:not([data-d-sheet~='closed'])")
      .hasAttribute(
        "aria-modal",
        "true",
        "the reopened sheet restores its active modal semantics"
      );
  });

  test("reopens after a scroll dismissal during the pending window", async function (assert) {
    const OriginalIntersectionObserver = window.IntersectionObserver;
    const OriginalRequestAnimationFrame = window.requestAnimationFrame;
    const OriginalCancelAnimationFrame = window.cancelAnimationFrame;
    const intersectionObservers = [];
    let sheetController;
    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };

    window.IntersectionObserver = class {
      constructor(callback, options) {
        this.callback = callback;
        this.options = options;
        intersectionObservers.push(this);
      }

      observe() {}
      unobserve() {}
      disconnect() {}
    };

    try {
      await render(
        <template>
          <DSheet.Root as |sheet|>
            <div hidden {{didInsert captureSheet sheet}}></div>
            <DSheet.Trigger @sheet={{sheet}} class="open-after-scroll-dismiss">
              Open
            </DSheet.Trigger>
            <DSheet.Portal @sheet={{sheet}}>
              <DSheet.View @sheet={{sheet}}>
                <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                  <ContentTag>Content</ContentTag>
                </DSheet.Content>
              </DSheet.View>
            </DSheet.Portal>
          </DSheet.Root>
        </template>
      );

      await click(".open-after-scroll-dismiss");
      await waitUntil(
        () =>
          sheetController.state.openness.isOpen &&
          sheetController.state.staging.isNone,
        {
          timeout: 3000,
          timeoutMessage: "the initial sheet finishes opening",
        }
      );
      await settled();

      const initialController = sheetController;
      const concealedView = find("[data-d-sheet~='view']");
      const concealedContent = find("[data-d-sheet~='content']");
      const concealedScrollContainer = find(
        "[data-d-sheet~='scroll-container']"
      );
      const intersectionObserver = intersectionObservers.find(
        ({ options }) => options?.root === concealedView
      );

      assert.notStrictEqual(
        intersectionObserver,
        undefined,
        "the open sheet observes content visibility for scroll dismissal"
      );

      let swipeOutFrame;
      window.requestAnimationFrame = (callback) => {
        swipeOutFrame = callback;
        return -1;
      };
      window.cancelAnimationFrame = () => {
        swipeOutFrame = undefined;
      };

      try {
        intersectionObserver.callback([{ isIntersecting: false }]);
      } finally {
        window.requestAnimationFrame = OriginalRequestAnimationFrame;
        window.cancelAnimationFrame = OriginalCancelAnimationFrame;
      }

      assert.strictEqual(
        concealedContent.style.getPropertyValue("pointer-events"),
        "none",
        "the outgoing content ignores pointer events"
      );
      assert.strictEqual(
        concealedScrollContainer.style.getPropertyValue("clip-path"),
        "inset(0px)",
        "the outgoing scroll container is clipped"
      );
      assert.strictEqual(
        concealedScrollContainer.style.getPropertyValue("height"),
        "1px",
        "the outgoing scroll container is collapsed vertically"
      );
      assert.strictEqual(
        concealedScrollContainer.style.getPropertyValue("width"),
        "1px",
        "the outgoing scroll container is collapsed horizontally"
      );
      assert.strictEqual(
        concealedView.style.getPropertyValue("left"),
        "-100px",
        "the outgoing view is moved beyond the left edge"
      );
      assert.strictEqual(
        concealedView.style.getPropertyValue("opacity"),
        "0",
        "the outgoing view is transparent"
      );
      assert.strictEqual(
        concealedView.style.getPropertyValue("pointer-events"),
        "none",
        "the outgoing view ignores pointer events"
      );
      assert.strictEqual(
        concealedView.style.getPropertyValue("position"),
        "fixed",
        "the outgoing view is removed from its scrolling layout"
      );
      assert.strictEqual(
        concealedView.style.getPropertyValue("top"),
        "-100px",
        "the outgoing view is moved beyond the top edge"
      );
      assert.strictEqual(
        typeof swipeOutFrame,
        "function",
        "the observer queues its swipe-out frame"
      );

      swipeOutFrame();

      await waitUntil(() => sheetController.state.openness.isClosedPending, {
        timeout: 3000,
        timeoutMessage: "the observer-triggered swipe reaches closed pending",
      });

      assert.strictEqual(
        find("[data-d-sheet~='view']"),
        concealedView,
        "the pending window keeps the concealed View mounted"
      );
      assert.true(
        concealedView.isConnected,
        "the concealed View remains connected during the pending window"
      );
      assert.strictEqual(
        concealedScrollContainer.style.getPropertyValue("scroll-snap-type"),
        "none",
        "the observer frame disables scroll snapping"
      );

      await click(".open-after-scroll-dismiss");
      await waitUntil(
        () =>
          sheetController.state.openness.isOpen &&
          sheetController.state.staging.isNone,
        {
          timeout: 3000,
          timeoutMessage: "the pending sheet finishes reopening",
        }
      );

      const reopenedView = find("[data-d-sheet~='view']");
      const reopenedContent = find("[data-d-sheet~='content']");
      const reopenedScrollContainer = find(
        "[data-d-sheet~='scroll-container']"
      );

      assert.strictEqual(
        sheetController,
        initialController,
        "the pending lifecycle reuses its controller"
      );
      assert.notStrictEqual(
        reopenedView,
        concealedView,
        "the pending flush remounts the concealed View"
      );
      assert.false(
        concealedView.isConnected,
        "the pending flush disconnects the concealed View"
      );
      assert.true(reopenedView.isConnected, "the reopened View is connected");
      assert.strictEqual(
        reopenedContent.style.getPropertyValue("pointer-events"),
        "",
        "the reopened content restores pointer events"
      );
      assert.strictEqual(
        reopenedScrollContainer.style.getPropertyValue("clip-path"),
        "",
        "the reopened scroll container is not clipped"
      );
      assert.strictEqual(
        reopenedScrollContainer.style.getPropertyValue("height"),
        "",
        "the reopened scroll container has no forced height"
      );
      assert.strictEqual(
        reopenedScrollContainer.style.getPropertyValue("width"),
        "",
        "the reopened scroll container has no forced width"
      );
      assert.strictEqual(
        reopenedScrollContainer.style.getPropertyValue("scroll-snap-type"),
        "",
        "the reopened scroll container restores scroll snapping"
      );
      assert.strictEqual(
        reopenedView.style.getPropertyValue("left"),
        "",
        "the reopened View has no forced horizontal offset"
      );
      assert.strictEqual(
        reopenedView.style.getPropertyValue("opacity"),
        "",
        "the reopened View has no forced opacity"
      );
      assert.strictEqual(
        reopenedView.style.getPropertyValue("pointer-events"),
        "",
        "the reopened View restores pointer events"
      );
      assert.strictEqual(
        reopenedView.style.getPropertyValue("position"),
        "",
        "the reopened View has no forced position"
      );
      assert.strictEqual(
        reopenedView.style.getPropertyValue("top"),
        "",
        "the reopened View has no forced vertical offset"
      );
      assert.true(
        sheetController.state.openness.isOpen,
        "the remounted sheet completes its open lifecycle"
      );
    } finally {
      window.IntersectionObserver = OriginalIntersectionObserver;
      window.requestAnimationFrame = OriginalRequestAnimationFrame;
      window.cancelAnimationFrame = OriginalCancelAnimationFrame;
    }
  });

  test("detects body layers added after an inert sheet", async function (assert) {
    let externalLayer;
    let externalButton;

    try {
      await render(
        <template>
          <DSheet.Root @defaultPresented={{true}} as |sheet|>
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

      await waitFor(
        "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
      );

      externalLayer = document.createElement("div");
      externalLayer.className = "external-body-layer";
      externalButton = document.createElement("button");
      externalButton.type = "button";
      externalButton.className = "external-body-layer-button";
      externalButton.textContent = "Layer";
      externalLayer.appendChild(externalButton);
      document.body.appendChild(externalLayer);

      await settled();
      await waitUntil(() => !externalLayer.inert, { timeout: 3000 });

      await click(externalButton);

      assert
        .dom("[data-d-sheet~='view']")
        .exists("clicks in detected body layers are ignored");
    } finally {
      externalLayer?.remove();
    }
  });

  test("view options return to defaults when args become undefined", async function (assert) {
    const state = new (class {
      @tracked swipe = false;
      @tracked tracks = "right";
      @tracked onClickOutside = { dismiss: false };
    })();
    let sheetController;

    const captureSheet = (_element, [sheet]) => {
      sheetController = sheet;
    };

    const resetSwipe = () => {
      state.swipe = undefined;
    };

    const resetOnClickOutside = () => {
      state.onClickOutside = undefined;
    };

    const resetTracks = () => {
      state.tracks = undefined;
    };

    await render(
      <template>
        <button type="button" class="outside-click-target">Outside</button>

        <DSheet.Root @defaultPresented={{true}} as |sheet|>
          <div hidden {{didInsert captureSheet sheet}}></div>
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View
              @sheet={{sheet}}
              @swipe={{state.swipe}}
              @tracks={{state.tracks}}
              @inertOutside={{false}}
              @onClickOutside={{state.onClickOutside}}
            >
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>
                  <button
                    type="button"
                    class="reset-swipe"
                    {{on "click" resetSwipe}}
                  >
                    Reset swipe
                  </button>
                  <button
                    type="button"
                    class="reset-tracks"
                    {{on "click" resetTracks}}
                  >
                    Reset tracks
                  </button>
                  <button
                    type="button"
                    class="reset-click-outside"
                    {{on "click" resetOnClickOutside}}
                  >
                    Reset click outside
                  </button>
                </ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    await waitFor(
      "[data-d-sheet~='view'][data-d-sheet~='staging-none']:not([data-d-sheet~='closed'])"
    );

    assert
      .dom("[data-d-sheet~='scroll-container']")
      .hasAttribute(
        "data-d-sheet",
        /swipe-disabled/,
        "false swipe args disable swiping"
      );
    assert
      .dom("[data-d-sheet~='view']")
      .hasAttribute(
        "data-d-sheet",
        /right/,
        "the explicit track configures the view"
      );
    assert.strictEqual(
      sheetController.dimensions.view.travelAxis.unitless,
      parseFloat(getComputedStyle(find("[data-d-sheet~='view']")).width),
      "initial horizontal dimensions are measured from the rendered track"
    );

    await click(".reset-swipe");
    await waitUntil(
      () =>
        !find("[data-d-sheet~='scroll-container']")
          ?.dataset.dSheet.split(" ")
          .includes("swipe-disabled")
    );

    assert.false(
      find("[data-d-sheet~='scroll-container']")
        ?.dataset.dSheet.split(" ")
        .includes("swipe-disabled"),
      "undefined swipe args return to the default"
    );

    const horizontalDimensions = sheetController.dimensions;
    await click(".reset-tracks");
    await waitUntil(
      () =>
        find("[data-d-sheet~='view']")
          ?.dataset.dSheet.split(" ")
          .includes("bottom") &&
        sheetController.dimensions?.view &&
        sheetController.dimensions !== horizontalDimensions
    );

    assert
      .dom("[data-d-sheet~='view']")
      .hasAttribute(
        "data-d-sheet",
        /bottom/,
        "undefined tracks return to the default"
      );
    assert.strictEqual(
      sheetController.dimensions.view.travelAxis.unitless,
      parseFloat(getComputedStyle(find("[data-d-sheet~='view']")).height),
      "vertical dimensions are measured after the rendered track updates"
    );

    await click(".outside-click-target");

    assert
      .dom("[data-d-sheet~='view']")
      .exists("the custom click-outside handler is still active");

    await click(".reset-click-outside");
    await click(".outside-click-target");
    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 5000 });

    assert
      .dom("[data-d-sheet~='view']")
      .doesNotExist("undefined handlers return to the default behavior");
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
    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 5000 });

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
    await waitUntil(() => !find("[data-d-sheet~='view']"), { timeout: 5000 });

    assert.false(state.presented, "the controlled root is dismissed");
    assert.deepEqual(
      changes,
      [true, false],
      "header close emits a single close change"
    );
  });
});
