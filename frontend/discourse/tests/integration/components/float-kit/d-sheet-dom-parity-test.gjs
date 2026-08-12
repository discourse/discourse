import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import {
  clearRender,
  find,
  findAll,
  focus,
  render,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { isInsidePreventionContainer } from "discourse/float-kit/components/d-scroll/focus-scroll-utils";
import DSheet from "discourse/float-kit/components/d-sheet";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SKIPPED_ANIMATION_SETTINGS = { skip: true };
const ANIMATED_ANIMATION_SETTINGS = { skip: false };

function createBackdropSheet(overrides = {}) {
  return {
    isStackAnimating: false,
    registerBackdrop() {},
    registerTravelAnimation() {
      return () => {};
    },
    unregisterBackdrop() {},
    ...overrides,
  };
}

module("Integration | Component | FloatKit | DSheet", function (hooks) {
  setupRenderingTest(hooks);
  hooks.afterEach(() => sinon.restore());

  test("Root updates its component registration when componentId changes", async function (assert) {
    const state = new (class {
      @tracked componentId = "first-sheet";
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template><DSheet.Root @componentId={{state.componentId}} /></template>
    );

    const root = sheetLayerStore.getRootByComponentId("first-sheet");
    assert.notStrictEqual(
      root,
      undefined,
      "the initial component ID resolves to the Root"
    );

    state.componentId = "second-sheet";
    await settled();

    assert.strictEqual(
      sheetLayerStore.getRootByComponentId("first-sheet"),
      undefined,
      "the previous component ID is released"
    );
    assert.strictEqual(
      sheetLayerStore.getRootByComponentId("second-sheet"),
      root,
      "the new component ID resolves to the same Root"
    );

    await clearRender();

    assert.strictEqual(
      sheetLayerStore.getRootByComponentId("second-sheet"),
      undefined,
      "the current component ID is released on destruction"
    );
  });

  test("Root reparents an open sheet when forComponent changes", async function (assert) {
    const state = new (class {
      @tracked stackId = "dynamic-stack-a";
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const sheetStackRegistry = this.owner.lookup(
      "service:sheet-stack-registry"
    );

    await render(
      <template>
        <DSheet.Stack.Root @componentId="dynamic-stack-a" />
        <DSheet.Stack.Root @componentId="dynamic-stack-b" />
        <DSheet.Root
          @componentId="dynamic-stack-sheet"
          @defaultPresented={{true}}
          @forComponent={{state.stackId}}
          as |sheet|
        >
          <DSheet.View
            @enteringAnimationSettings={{SKIPPED_ANIMATION_SETTINGS}}
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @swipe={{false}}
            as |view|
          >
            <view.Content>Content</view.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const root = sheetLayerStore.getRootByComponentId("dynamic-stack-sheet");
    await waitUntil(
      () => root.sheet.state.openness.isOpen && root.sheet.state.staging.isNone
    );

    const controller = root.sheet;
    const sheetId = controller.id;

    assert.true(
      sheetStackRegistry.stackSheets
        .get("dynamic-stack-a")
        .includes(controller),
      "the open sheet starts in the source stack"
    );

    state.stackId = "dynamic-stack-b";
    await settled();

    assert.strictEqual(
      root.sheet,
      controller,
      "reparenting preserves the live controller"
    );
    assert.strictEqual(root.sheet.id, sheetId, "the sheet ID remains stable");
    assert.false(
      sheetStackRegistry.stackSheets
        .get("dynamic-stack-a")
        .includes(controller),
      "the source stack releases the controller"
    );
    assert.strictEqual(
      sheetStackRegistry.getTopmostSheetInStack("dynamic-stack-b"),
      controller,
      "the target stack receives the same controller once"
    );
    assert.strictEqual(
      sheetStackRegistry.stackSheets.get("dynamic-stack-b").length,
      1,
      "the target stack contains no duplicate registration"
    );
  });

  test("a pending open follows the latest forComponent target", async function (assert) {
    const state = new (class {
      @tracked stackId = "pending-stack-a";
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const sheetStackRegistry = this.owner.lookup(
      "service:sheet-stack-registry"
    );
    const pendingCallbacks = new Map();
    const cleanupByStack = new Map([
      ["pending-stack-a", sinon.spy()],
      ["pending-stack-b", sinon.spy()],
    ]);

    await render(
      <template>
        <DSheet.Stack.Root @componentId="pending-stack-a" />
        <DSheet.Stack.Root @componentId="pending-stack-b" />
        <DSheet.Root
          @componentId="pending-stack-sheet"
          @forComponent={{state.stackId}}
          as |sheet|
        >
          <DSheet.View
            @enteringAnimationSettings={{SKIPPED_ANIMATION_SETTINGS}}
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @swipe={{false}}
            as |view|
          >
            <view.Content>Content</view.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const root = sheetLayerStore.getRootByComponentId("pending-stack-sheet");
    const parentByStack = new Map(
      ["pending-stack-a", "pending-stack-b"].map((stackId) => [
        stackId,
        {
          state: {
            subscribe(_machine, { callback }) {
              pendingCallbacks.set(stackId, callback);
              return cleanupByStack.get(stackId);
            },
          },
        },
      ])
    );

    sinon
      .stub(root, "getAnimatingParentSheet")
      .callsFake((stackId) => parentByStack.get(stackId));

    root.present();
    await settled();

    assert.true(
      pendingCallbacks.has("pending-stack-a"),
      "the initial open waits on the source parent"
    );

    state.stackId = "pending-stack-b";
    await settled();

    assert.true(
      cleanupByStack.get("pending-stack-a").calledOnce,
      "changing the target releases the source subscription"
    );
    assert.true(
      pendingCallbacks.has("pending-stack-b"),
      "the open resubscribes to the target parent"
    );

    pendingCallbacks.get("pending-stack-a")();

    assert.false(
      cleanupByStack.get("pending-stack-b").called,
      "a stale source callback cannot consume the target subscription"
    );
    assert.deepEqual(
      sheetStackRegistry.stackSheets.get("pending-stack-a"),
      [],
      "the stale callback cannot register in the source stack"
    );

    pendingCallbacks.get("pending-stack-b")();
    await settled();

    assert.true(
      cleanupByStack.get("pending-stack-b").calledOnce,
      "the target callback owns its subscription cleanup"
    );
    assert.strictEqual(
      sheetStackRegistry.getTopmostSheetInStack("pending-stack-b"),
      root.sheet,
      "the sheet opens in the latest target stack"
    );
  });

  test("a closing sheet defers a new stack target to its replacement", async function (assert) {
    const state = new (class {
      @tracked stackId = "closing-stack-a";
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const sheetStackRegistry = this.owner.lookup(
      "service:sheet-stack-registry"
    );

    await render(
      <template>
        <DSheet.Stack.Root @componentId="closing-stack-a" />
        <DSheet.Stack.Root @componentId="closing-stack-b" />
        <DSheet.Root
          @componentId="closing-stack-sheet"
          @defaultPresented={{true}}
          @forComponent={{state.stackId}}
          as |sheet|
        >
          <DSheet.View
            @enteringAnimationSettings={{SKIPPED_ANIMATION_SETTINGS}}
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @swipe={{false}}
            as |view|
          >
            <view.Content>Content</view.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const root = sheetLayerStore.getRootByComponentId("closing-stack-sheet");
    await waitUntil(
      () => root.sheet.state.openness.isOpen && root.sheet.state.staging.isNone
    );

    const closingController = root.sheet;
    const sheetId = closingController.id;

    sinon.stub(closingController.state.openness, "isOpen").get(() => false);
    sinon.stub(closingController.state.openness, "isClosing").get(() => true);
    state.stackId = "closing-stack-b";
    await settled();

    assert.true(
      sheetStackRegistry.stackSheets
        .get("closing-stack-a")
        .includes(closingController),
      "the closing controller remains owned by its source stack"
    );

    root.openSheet();
    root.handleSheetClosed();
    await settled();

    assert.notStrictEqual(
      root.sheet,
      closingController,
      "the reopen uses a replacement controller"
    );
    assert.strictEqual(root.sheet.id, sheetId, "the Root keeps its sheet ID");
    assert.false(
      sheetStackRegistry.stackSheets
        .get("closing-stack-a")
        .includes(closingController),
      "the old controller is removed from the source stack"
    );
    assert.strictEqual(
      sheetStackRegistry.getTopmostSheetInStack("closing-stack-b"),
      root.sheet,
      "the replacement opens in the latest target stack"
    );
  });

  test("an open no-op does not queue a later reopen", async function (assert) {
    const state = new (class {
      @tracked presented = false;
    })();
    const openingFrames = [];
    let root;
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");
    const onPresentedChange = (presented) => {
      state.presented = presented;
    };
    const onTravel = () => {
      if (!root?.sheet.state.openness.isOpening) {
        return;
      }

      openingFrames.push(true);
      if (openingFrames.length === 3) {
        state.presented = false;
      }
    };

    await render(
      <template>
        <DSheet.Root
          @componentId="opening-presentation-sheet"
          @onPresentedChange={{onPresentedChange}}
          @presented={{state.presented}}
          as |sheet|
        >
          <DSheet.Portal @sheet={{sheet}}>
            <DSheet.View
              @enteringAnimationSettings={{ANIMATED_ANIMATION_SETTINGS}}
              @onTravel={{onTravel}}
              @sheet={{sheet}}
              @swipe={{false}}
            >
              <DSheet.Content @sheet={{sheet}} as |ContentTag|>
                <ContentTag>Content</ContentTag>
              </DSheet.Content>
            </DSheet.View>
          </DSheet.Portal>
        </DSheet.Root>
      </template>
    );

    root = sheetLayerStore.getRootByComponentId("opening-presentation-sheet");

    state.presented = true;
    await waitUntil(() => openingFrames.length >= 3);
    await settled();
    await waitUntil(
      () => root.sheet.state.openness.isOpen && root.sheet.state.staging.isNone
    );

    assert.false(
      state.presented,
      "the ignored close leaves controlled presentation dismissed"
    );

    state.presented = true;
    await settled();

    const openController = root.sheet;
    state.presented = false;
    root.handleSheetClosed();
    await settled();

    assert.notStrictEqual(
      root.sheet,
      openController,
      "the completed close installs a fresh controller"
    );
    assert.true(
      root.sheet.state.staging.isNone,
      "the prior no-op open does not reopen the replacement"
    );
    assert.true(
      root.sheet.state.openness.isClosedSafeToUnmount,
      "the replacement stays closed after presentation becomes false"
    );
  });

  test("Root keeps one sheet ID across controller lifecycles", async function (assert) {
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template>
        <DSheet.Root @componentId="stable-sheet" as |sheet|>
          <DSheet.Trigger
            @forComponent="stable-sheet"
            class="stable-sheet-trigger"
          >
            Open
          </DSheet.Trigger>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            class="stable-sheet-view"
          />
        </DSheet.Root>
      </template>
    );

    const root = sheetLayerStore.getRootByComponentId("stable-sheet");
    const firstController = root.sheet;
    const sheetId = firstController.id;

    assert
      .dom(".stable-sheet-view")
      .doesNotHaveAttribute(
        "aria-modal",
        "a force-rendered closed view is not exposed as modal"
      );

    root.handleSheetClosed();
    await settled();

    assert.notStrictEqual(
      root.sheet,
      firstController,
      "a closed lifecycle still receives a fresh controller"
    );
    assert.strictEqual(
      root.sheet.id,
      sheetId,
      "the Root-owned sheet ID remains stable"
    );
    assert.dom(".stable-sheet-view").hasAttribute("id", sheetId);
    assert
      .dom(".stable-sheet-trigger")
      .hasAttribute(
        "aria-controls",
        sheetId,
        "external trigger relationships survive close and reopen"
      );
  });

  test("View protects its sheet-owned identity and focus attributes", async function (assert) {
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template>
        <DSheet.Root
          @componentId="protected-view-attributes"
          @sheetRole="dialog"
          as |sheet|
        >
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            id="consumer-view-id"
            role="alertdialog"
            tabindex="0"
            aria-labelledby="consumer-label"
            aria-describedby="consumer-description"
            class="protected-attributes-view"
          />
        </DSheet.Root>
      </template>
    );

    const { sheet } = sheetLayerStore.getRootByComponentId(
      "protected-view-attributes"
    );

    assert
      .dom(".protected-attributes-view")
      .hasAttribute("id", sheet.id, "the sheet ID cannot be replaced");
    assert
      .dom(".protected-attributes-view")
      .hasAttribute("role", "dialog", "the Root owns the sheet role");
    assert
      .dom(".protected-attributes-view")
      .hasAttribute("tabindex", "-1", "the View remains a focus fallback");
    assert
      .dom(".protected-attributes-view")
      .hasAttribute(
        "aria-labelledby",
        "consumer-label",
        "the consumer can replace the default label relationship"
      );
    assert
      .dom(".protected-attributes-view")
      .hasAttribute(
        "aria-describedby",
        "consumer-description",
        "the consumer can replace the default description relationship"
      );
  });

  test("Trigger exposes its structural touch-target tokens", async function (assert) {
    const sheet = {
      id: "sheet-id",
      isPresented: false,
      role: "dialog",
    };

    await render(
      <template>
        <DSheet.Trigger @sheet={{sheet}} data-d-sheet="consumer-trigger-token">
          Open
        </DSheet.Trigger>
      </template>
    );

    assert
      .dom("[data-d-sheet~='trigger']")
      .exists("the trigger exposes its structural token");
    assert
      .dom("[data-d-sheet~='touch-target-expander']")
      .exists("the trigger opts into the expanded touch target");
    assert
      .dom("[data-d-sheet~='consumer-trigger-token']")
      .exists("the trigger preserves consumer tokens");
    assert
      .dom("[data-d-sheet~='trigger']")
      .hasAttribute(
        "aria-expanded",
        "false",
        "the present trigger exposes presentation state"
      );
  });

  test("Root and action primitives retain Outlet behavior", async function (assert) {
    const animation = { opacity: [0, 1] };
    const registrations = [];
    const sheet = {
      detents: ["50vh", "100vh"],
      id: "action-sheet-id",
      isPresented: false,
      isStackAnimating: false,
      registerTravelAnimation(options) {
        registrations.push(options);
        return () => {};
      },
      role: "dialog",
    };

    await render(
      <template>
        <DSheet.Root class="root-outlet" @travelAnimation={{animation}}>
          <DSheet.Trigger
            class="trigger-outlet"
            @sheet={{sheet}}
            @travelAnimation={{animation}}
          >
            Open
          </DSheet.Trigger>
          <DSheet.Handle
            class="handle-outlet"
            @sheet={{sheet}}
            @travelAnimation={{animation}}
          />
        </DSheet.Root>
      </template>
    );

    assert
      .dom(".root-outlet[data-d-sheet~='root'][data-d-sheet~='outlet']")
      .exists("Root is an animation outlet");
    assert
      .dom(".trigger-outlet[data-d-sheet~='trigger'][data-d-sheet~='outlet']")
      .exists("Trigger is an animation outlet");
    assert
      .dom(".handle-outlet[data-d-sheet~='handle'][data-d-sheet~='outlet']")
      .exists("Handle inherits Trigger's animation outlet behavior");
    assert.deepEqual(
      registrations.map(({ target }) => target),
      [find(".trigger-outlet"), find(".handle-outlet")],
      "action animations register against their button elements"
    );
  });

  test("SpecialWrapper.Root defaults to a div", async function (assert) {
    const sheet = { tracks: "bottom" };

    await render(
      <template>
        <DSheet.SpecialWrapper.Root
          @sheet={{sheet}}
          class="default-special-wrapper"
        >
          Wrapped content
        </DSheet.SpecialWrapper.Root>
      </template>
    );

    assert
      .dom("div.default-special-wrapper")
      .hasText("Wrapped content", "the default element is a native div");
    assert
      .dom(".default-special-wrapper")
      .hasAttribute(
        "data-d-sheet",
        /special-wrapper-root/,
        "the default element receives the wrapper attributes"
      );
  });

  test("SpecialWrapper.Root preserves a contextual tag", async function (assert) {
    const sheet = { tracks: "bottom" };
    const SectionTag = <template>
      <section ...attributes>{{yield}}</section>
    </template>;

    await render(
      <template>
        <DSheet.SpecialWrapper.Root
          @sheet={{sheet}}
          @tag={{SectionTag}}
          class="contextual-special-wrapper"
        >
          Wrapped content
        </DSheet.SpecialWrapper.Root>
      </template>
    );

    assert
      .dom("section.contextual-special-wrapper")
      .hasText("Wrapped content", "the contextual element is rendered");
    assert
      .dom(".contextual-special-wrapper")
      .hasAttribute(
        "data-d-sheet",
        /special-wrapper-root/,
        "the contextual element receives the wrapper attributes"
      );
  });

  test("SpecialWrapper emits the ScrollTrap DOM contract", async function (assert) {
    const sheet = { tracks: "bottom" };

    await render(
      <template>
        <DSheet.SpecialWrapper.Root
          @sheet={{sheet}}
          class="structural-special-wrapper"
        >
          <DSheet.SpecialWrapper.Content class="special-wrapper-content">
            Wrapped content
          </DSheet.SpecialWrapper.Content>
        </DSheet.SpecialWrapper.Root>
      </template>
    );

    const wrapper = assert.dom(".structural-special-wrapper");

    wrapper.hasAttribute(
      "data-d-sheet",
      /scroll-trap-root/,
      "the wrapper is a scroll-trap root"
    );
    wrapper.hasAttribute(
      "data-d-sheet",
      /scroll-trap-marker/,
      "focus traversal can identify the trap boundary"
    );
    wrapper.hasAttribute(
      "data-d-sheet",
      /scroll-trap-end/,
      "the wrapper exposes the end-of-trap token"
    );
    wrapper.hasAttribute(
      "data-d-sheet",
      /scroll-horizontal/,
      "the trap axis is perpendicular to bottom-sheet travel"
    );
    assert
      .dom(".special-wrapper-content")
      .hasAttribute(
        "data-d-sheet",
        /scroll-trap-stabilizer/,
        "Content emits the stabilizer element"
      );
  });

  test("Content keeps detent markers keyed by index", async function (assert) {
    const state = new (class {
      @tracked detents = ["20px", "40px"];
    })();

    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.View
            @detents={{state.detents}}
            @sheet={{sheet}}
            @shouldRenderView={{true}}
          >
            <DSheet.Content @sheet={{sheet}} />
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const initialMarkers = findAll("[data-d-sheet~='detent-marker']");

    assert.strictEqual(
      initialMarkers.length,
      3,
      "configured detents and the full-content detent each receive a marker"
    );

    state.detents = ["40px", "20px"];
    await settled();

    const updatedMarkers = findAll("[data-d-sheet~='detent-marker']");

    assert.strictEqual(
      updatedMarkers[0],
      initialMarkers[0],
      "the first marker retains its index-owned element"
    );
    assert.strictEqual(
      updatedMarkers[1],
      initialMarkers[1],
      "the second marker retains its index-owned element"
    );
    assert.strictEqual(
      updatedMarkers[0].style.getPropertyValue("--d-sheet-marker-prev"),
      "0px",
      "the first marker has no previous detent"
    );
    assert.strictEqual(
      updatedMarkers[0].style.getPropertyValue("--d-sheet-marker-current"),
      "40px",
      "the first marker receives the updated current detent"
    );
    assert.strictEqual(
      updatedMarkers[1].style.getPropertyValue("--d-sheet-marker-prev"),
      "40px",
      "the second marker receives the updated previous detent"
    );
    assert.strictEqual(
      updatedMarkers[1].style.getPropertyValue("--d-sheet-marker-index"),
      "1",
      "the marker exposes its stable index"
    );
  });

  test("Root exposes sheetRole without an implicit role", async function (assert) {
    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.View
            class="primitive-view"
            @sheet={{sheet}}
            @shouldRenderView={{true}}
          />
        </DSheet.Root>
      </template>
    );

    assert
      .dom(".primitive-view")
      .doesNotHaveAttribute("role", "the primitive has no default role");

    await clearRender();
    await render(
      <template>
        <DSheet.Root @sheetRole="dialog" as |sheet|>
          <DSheet.View
            class="primitive-view"
            @sheet={{sheet}}
            @shouldRenderView={{true}}
          />
        </DSheet.Root>
      </template>
    );

    assert
      .dom(".primitive-view")
      .hasAttribute("role", "dialog", "sheetRole configures the view role");

    await clearRender();
    await render(
      <template>
        <DSheet.Root @role="alertdialog" as |sheet|>
          <DSheet.View
            class="primitive-view"
            @sheet={{sheet}}
            @shouldRenderView={{true}}
          />
        </DSheet.Root>
      </template>
    );

    assert
      .dom(".primitive-view")
      .hasAttribute(
        "role",
        "alertdialog",
        "the previous role argument remains an alias"
      );
  });

  test("View retains its focus outline as the fallback target", async function (assert) {
    await render(
      <template>
        <DSheet.Root @inertOutside={{false}} as |sheet|>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            class="fallback-focus-view"
          />
        </DSheet.Root>
      </template>
    );

    await focus(".fallback-focus-view");

    const view = find(".fallback-focus-view");
    assert.dom(view).isFocused("the View can receive fallback focus");
    assert.notStrictEqual(
      getComputedStyle(view).outlineStyle,
      "none",
      "the user-agent focus outline remains visible"
    );
  });

  test("View configures only when its configuration or Controller changes", async function (assert) {
    const initialConfigureTiming = [];
    const firstConfigure = sinon.spy(() => {
      initialConfigureTiming.push(
        document.querySelector(".configuration-identity-view") !== null
      );
    });
    const replacementConfigure = sinon.spy();
    const createController = (id, configure) => ({
      configure,
      effectiveSwipeTrapClass: null,
      handleFocus() {},
      id,
      inertOutside: true,
      isScrollTrapActive: false,
      isStackAnimating: false,
      nativeFocusScrollPrevention: false,
      primaryScrollTrapAxisClass: "scroll-vertical",
      registerView() {},
      role: "dialog",
      scrollContainerShouldBePassThrough: false,
      state: {
        openness: { isClosed: false },
        staging: { current: "none" },
        stuck: { isBack: false, isFront: false },
      },
      tracks: "bottom",
      unregisterView() {},
    });
    const firstController = createController("first-sheet", firstConfigure);
    const replacementController = createController(
      "replacement-sheet",
      replacementConfigure
    );
    const state = new (class {
      @tracked controller = firstController;
      @tracked marker = "initial";
      @tracked tracks = "bottom";
    })();

    await render(
      <template>
        <DSheet.View
          @inertOutside={{true}}
          @sheet={{state.controller}}
          @shouldRenderView={{true}}
          @tracks={{state.tracks}}
          class="configuration-identity-view"
          data-marker={{state.marker}}
        />
      </template>
    );

    assert.strictEqual(
      firstConfigure.callCount,
      1,
      "constructor and initial modifier setup share one configuration"
    );
    assert.deepEqual(
      initialConfigureTiming,
      [false],
      "the initial configuration is applied before the View renders"
    );

    state.marker = "updated";
    await settled();

    assert
      .dom(".configuration-identity-view")
      .hasAttribute("data-marker", "updated", "the unrelated render completes");
    assert.strictEqual(
      firstConfigure.callCount,
      1,
      "an unrelated render does not reconfigure the sheet"
    );

    state.tracks = "top";
    await settled();

    assert.strictEqual(
      firstConfigure.callCount,
      2,
      "a configuration argument change configures once"
    );
    assert.strictEqual(
      firstConfigure.lastCall.args[0].tracks,
      "top",
      "the changed configuration is forwarded"
    );

    state.controller = replacementController;
    await settled();

    assert.strictEqual(
      firstConfigure.callCount,
      2,
      "the previous Controller is not configured again"
    );
    assert.strictEqual(
      replacementConfigure.callCount,
      1,
      "a replacement Controller receives the current configuration once"
    );
    assert.strictEqual(
      replacementConfigure.firstCall.args[0].tracks,
      "top",
      "the replacement receives the latest configuration"
    );
  });

  test("hidden View configures a replacement Controller before reopening", async function (assert) {
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template>
        <DSheet.Root @componentId="hidden-view-configuration" as |sheet|>
          <DSheet.View
            @enteringAnimationSettings={{SKIPPED_ANIMATION_SETTINGS}}
            @sheet={{sheet}}
            @tracks="right"
          />
        </DSheet.Root>
      </template>
    );

    const root = sheetLayerStore.getRootByComponentId(
      "hidden-view-configuration"
    );
    const firstController = root.sheet;

    root.handleSheetClosed();
    await settled();

    assert.notStrictEqual(
      root.sheet,
      firstController,
      "the closed lifecycle creates a replacement Controller"
    );
    assert.strictEqual(
      root.sheet.tracks,
      "right",
      "the hidden View configures the replacement track"
    );
    root.openSheet();

    assert.true(
      root.sheet.state.skip.isOpening,
      "reopening synchronizes the View's opening behavior"
    );
    assert.true(
      root.sheet.state.staging.isOpen,
      "the second open uses the configured skipped-opening path"
    );
  });

  test("View inherits dynamic Root inertOutside configuration", async function (assert) {
    const state = new (class {
      @tracked inertOutside = true;
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template>
        <DSheet.Root
          @componentId="inherited-inert-sheet"
          @inertOutside={{state.inertOutside}}
          as |sheet|
        >
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            class="inherited-inert-view"
          />
        </DSheet.Root>
      </template>
    );

    const { sheet } = sheetLayerStore.getRootByComponentId(
      "inherited-inert-sheet"
    );

    assert.true(sheet.inertOutside, "the initial Root option is inherited");

    state.inertOutside = false;
    await settled();

    assert.false(sheet.inertOutside, "the inherited option remains reactive");
    assert
      .dom(".inherited-inert-view")
      .hasAttribute(
        "data-d-sheet",
        /no-pointer-events/,
        "the View renders the updated inherited behavior"
      );
  });

  test("explicit View inertOutside outranks later Root changes", async function (assert) {
    const state = new (class {
      @tracked inertOutside = true;
    })();
    const sheetLayerStore = this.owner.lookup("service:sheet-layer-store");

    await render(
      <template>
        <DSheet.Root
          @componentId="explicit-inert-sheet"
          @inertOutside={{state.inertOutside}}
          as |sheet|
        >
          <DSheet.View
            @inertOutside={{true}}
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            class="explicit-inert-view"
          />
        </DSheet.Root>
      </template>
    );

    const { sheet } = sheetLayerStore.getRootByComponentId(
      "explicit-inert-sheet"
    );

    state.inertOutside = false;
    await settled();

    assert.true(
      sheet.inertOutside,
      "the unchanged explicit View option remains authoritative"
    );
    assert.false(
      find(".explicit-inert-view")
        .getAttribute("data-d-sheet")
        .split(" ")
        .includes("no-pointer-events"),
      "the explicit View behavior is preserved"
    );
  });

  test("sheet primitives preserve consumer data tokens", async function (assert) {
    await render(
      <template>
        <DSheet.Root
          @inertOutside={{false}}
          data-d-sheet="consumer-root"
          as |sheet|
        >
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            data-d-sheet="consumer-view"
          >
            <DSheet.Title @sheet={{sheet}} data-d-sheet="consumer-title">
              Title
            </DSheet.Title>
            <DSheet.Description
              @sheet={{sheet}}
              data-d-sheet="consumer-description"
            >
              Description
            </DSheet.Description>
            <DSheet.Backdrop
              @sheet={{sheet}}
              data-d-sheet="consumer-backdrop"
            />
            <DSheet.BleedingBackground
              @sheet={{sheet}}
              data-d-sheet="consumer-background"
            />
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    for (const [consumerToken, structuralToken] of [
      ["consumer-root", "root"],
      ["consumer-view", "view"],
      ["consumer-title", "title"],
      ["consumer-description", "description"],
      ["consumer-backdrop", "backdrop"],
      ["consumer-background", "bleeding-background"],
    ]) {
      assert
        .dom(`[data-d-sheet~='${consumerToken}']`)
        .hasAttribute(
          "data-d-sheet",
          new RegExp(`(?:^|\\s)${structuralToken}(?:\\s|$)`),
          `${structuralToken} remains present with consumer tokens`
        );
    }

    assert
      .dom("[data-d-sheet~='consumer-view']")
      .hasAttribute(
        "data-d-sheet",
        /no-pointer-events/,
        "View inherits the port's Root-level inertOutside option"
      );
  });

  test("Handle only exposes expanded state for dismiss actions", async function (assert) {
    const sheet = {
      detents: ["50vh", "100vh"],
      id: "sheet-id",
      isPresented: true,
    };

    await render(
      <template>
        <DSheet.Handle @sheet={{sheet}} class="step-handle" />
        <DSheet.Handle
          @sheet={{sheet}}
          @action="dismiss"
          class="dismiss-handle"
        >
          Custom dismiss label
        </DSheet.Handle>
      </template>
    );

    assert
      .dom(".step-handle")
      .doesNotHaveAttribute(
        "aria-expanded",
        "the default step action does not expose presentation state"
      );
    assert
      .dom(".dismiss-handle")
      .hasAttribute(
        "aria-expanded",
        "true",
        "the dismiss action exposes presentation state"
      );
    assert
      .dom(".step-handle[data-d-sheet~='trigger']")
      .exists("the handle retains Trigger's structural token");
    assert
      .dom(".dismiss-handle > .sr-only")
      .hasText(
        "Custom dismiss label",
        "custom handle content remains visually hidden"
      );
  });

  test("Outlet merges structural and animation state tokens", async function (assert) {
    const sheet = new (class {
      @tracked isStackAnimating = false;
    })();

    await render(
      <template>
        <DSheet.Outlet @sheet={{sheet}} data-d-sheet="consumer-token">
          Outlet content
        </DSheet.Outlet>
      </template>
    );

    assert
      .dom("[data-d-sheet~='outlet']")
      .hasAttribute(
        "data-d-sheet",
        /consumer-token/,
        "the outlet preserves consumer tokens"
      );
    assert
      .dom("[data-d-sheet~='animating']")
      .doesNotExist("the outlet is initially idle");

    sheet.isStackAnimating = true;
    await settled();

    assert
      .dom("[data-d-sheet~='outlet']")
      .hasAttribute(
        "data-d-sheet",
        /animating/,
        "the outlet reflects animation state"
      );
  });

  test("Outlet scopes travel styles to the sheet lifecycle", async function (assert) {
    const registrations = [];
    const state = new (class {
      @tracked
      consumerStyle = trustHTML(
        "color: blue; transform-origin: 25% 25%; will-change: contents;"
      );
      @tracked isActive = false;
      @tracked
      travelAnimation = {
        color: "red",
        opacity: [0, 1],
        scale: [0.8, 1],
        transformOrigin: "0 50%",
      };
    })();
    const sheet = {
      isStackAnimating: false,
      state: { longRunning: state },
      registerTravelAnimation(animation) {
        registrations.push(animation);
        return () => {};
      },
    };

    await render(
      <template>
        <DSheet.Outlet
          @sheet={{sheet}}
          @travelAnimation={{state.travelAnimation}}
          class="travel-lifecycle-outlet"
          style={{state.consumerStyle}}
        />
      </template>
    );

    const outlet = find(".travel-lifecycle-outlet");

    assert.strictEqual(
      outlet.style.color,
      "blue",
      "the consumer style is retained while the sheet is idle"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "contents",
      "the consumer will-change is retained while the sheet is idle"
    );

    state.isActive = true;
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "red",
      "the travel style is applied while the sheet is active"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "0px 50%",
      "all declarative travel styles follow the lifecycle"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "opacity, transform, contents",
      "composited animation properties extend the consumer hint"
    );
    assert.strictEqual(
      registrations.length,
      1,
      "a lifecycle-only update keeps the animation registration"
    );

    state.consumerStyle = trustHTML(
      "color: green; transform-origin: 40% 40%; will-change: scroll-position;"
    );
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "green",
      "a consumer update can replace an active modifier style"
    );

    state.travelAnimation = {
      color: "red",
      willChange: "layout",
    };
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "red",
      "the replacement configuration layers over the current consumer style"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "40% 40%",
      "configuration replacement does not restore a stale consumer style"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "scroll-position",
      "animation-config willChange does not leak into lifecycle styles"
    );
    assert.strictEqual(
      registrations.length,
      2,
      "the replacement animation is registered once"
    );

    state.isActive = false;
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "green",
      "the current consumer style is restored when the lifecycle ends"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "40% 40%",
      "the current consumer transform origin is retained"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "scroll-position",
      "the current consumer will-change is retained"
    );
  });

  test("Stack Outlet scopes stacking styles to the active sheet count", async function (assert) {
    const stackId = "outlet-style-stack";
    const registry = this.owner.lookup("service:sheet-stack-registry");
    const state = new (class {
      @tracked
      consumerStyle = trustHTML(
        "color: blue; opacity: 0.4 !important; transform: rotate(5deg) !important; transform-origin: 25% 25%; will-change: contents;"
      );
    })();
    const stackingAnimation = {
      color: "red",
      opacity: [1, 0],
      scale: [1, 0.9],
      transformOrigin: "0 50%",
    };

    await render(
      <template>
        <DSheet.Stack.Root @componentId={{stackId}} as |stack|>
          <stack.Outlet
            @stackingAnimation={{stackingAnimation}}
            class="stack-lifecycle-outlet"
            style={{state.consumerStyle}}
          />
        </DSheet.Stack.Root>
      </template>
    );

    const outlet = find(".stack-lifecycle-outlet");
    const stack = registry.stacks.get(stackId);

    assert.strictEqual(
      outlet.style.color,
      "blue",
      "the consumer style is retained while the stack is empty"
    );

    registry.incrementStackingCount(stackId);
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "red",
      "the stacking style is applied while a sheet is active"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "0px 50%",
      "all declarative stacking styles follow the sheet count"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "opacity, transform, contents",
      "the stack advertises its composited animation properties"
    );
    assert.strictEqual(
      stack.stackingAnimations.length,
      1,
      "a count-only update keeps the animation registration"
    );

    stack.stackingAnimations[0].callback(1);
    state.consumerStyle = trustHTML(
      "color: blue; opacity: 0.6 !important; transform: rotate(15deg) !important; transform-origin: 25% 25%; will-change: contents;"
    );
    await settled();
    stack.stackingAnimations[0].callback(0.5);

    registry.decrementStackingCount(stackId);
    await settled();

    assert.strictEqual(
      outlet.style.color,
      "blue",
      "the consumer style is restored when the stack empties"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "25% 25%",
      "the consumer transform origin is restored"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "contents",
      "the consumer will-change is restored"
    );
    assert.strictEqual(
      outlet.style.transform,
      "rotate(15deg)",
      "the latest consumer transform is restored after the animation"
    );
    assert.strictEqual(
      outlet.style.getPropertyPriority("transform"),
      "important",
      "the consumer transform priority is restored"
    );
    assert.strictEqual(
      outlet.style.opacity,
      "0.6",
      "the latest consumer opacity is restored after the animation"
    );
    assert.strictEqual(
      outlet.style.getPropertyPriority("opacity"),
      "important",
      "the consumer opacity priority is restored"
    );
  });

  test("Outlet preserves animated styles while replacing its configuration", async function (assert) {
    const registrations = [];
    const unregistrations = [];
    const state = new (class {
      @tracked
      stackingAnimation = {
        scale: [1, 0.933],
        transformOrigin: "0 50%",
      };
    })();
    const sheet = {
      isStackAnimating: true,
      sheetStackRegistry: {
        stackingCounts: new Map([["configuration-stack", 1]]),
      },
      stackId: "configuration-stack",
      state: { longRunning: { isActive: true } },
      registerStackingAnimation(animation) {
        registrations.push(animation);
        return () => unregistrations.push(animation);
      },
    };

    await render(
      <template>
        <DSheet.Outlet
          class="configuration-outlet"
          @sheet={{sheet}}
          @stackingAnimation={{state.stackingAnimation}}
          style="transform: rotate(4deg) !important; transform-origin: 25% 25%; will-change: contents;"
        />
      </template>
    );

    const outlet = find(".configuration-outlet");
    registrations[0].callback(1);
    const persistedTransform = outlet.style.transform;

    state.stackingAnimation = {
      scale: [1, 0.933],
      transformOrigin: "50% 0",
    };
    await settled();

    assert.strictEqual(
      outlet.style.transform,
      persistedTransform,
      "the completed transform remains painted across registration changes"
    );
    assert.strictEqual(
      registrations.length,
      2,
      "the replacement animation is registered"
    );
    assert.strictEqual(
      unregistrations.length,
      1,
      "the previous animation is unregistered"
    );
    assert.deepEqual(
      [...registrations[1].animatedProperties],
      ["transform"],
      "the sheet owns the persisted animated property"
    );
    assert.strictEqual(
      outlet.style.transformOrigin,
      "50% 0px",
      "declarative static styles update with the configuration"
    );

    await clearRender();

    assert.strictEqual(
      outlet.style.transformOrigin,
      "25% 25%",
      "the modifier restores the consumer style on destruction"
    );
    assert.strictEqual(
      outlet.style.willChange,
      "contents",
      "the modifier restores the consumer will-change on destruction"
    );
    assert.strictEqual(
      outlet.style.transform,
      "rotate(4deg)",
      "configuration replacement retains the consumer transform for teardown"
    );
    assert.strictEqual(
      outlet.style.getPropertyPriority("transform"),
      "important",
      "configuration replacement retains the consumer transform priority"
    );
  });

  test("Content retains its element when animation arguments change", async function (assert) {
    const state = new (class {
      @tracked
      stackingAnimation = {
        scale: [1, 0.933],
        transformOrigin: "0 50%",
      };
    })();

    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.View @sheet={{sheet}} @shouldRenderView={{true}}>
            <DSheet.Content
              @sheet={{sheet}}
              @stackingAnimation={{state.stackingAnimation}}
              as |ContentTag|
            >
              <ContentTag class="stable-content">Content</ContentTag>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const content = find(".stable-content");

    state.stackingAnimation = {
      scale: [1, 0.933],
      transformOrigin: "50% 0",
    };
    await settled();

    assert.strictEqual(
      find(".stable-content"),
      content,
      "the yielded Content element is not destroyed and recreated"
    );
    assert.notStrictEqual(
      content.style.transformOrigin,
      "0px 50%",
      "the retained element still receives reactive animation arguments"
    );
  });

  test("Content clears its default fill only while a bleeding background is present", async function (assert) {
    const state = new (class {
      @tracked showBackground = false;
    })();

    await render(
      <template>
        <DSheet.Root @inertOutside={{false}} as |sheet|>
          <DSheet.View @sheet={{sheet}} @shouldRenderView={{true}}>
            <DSheet.Content @sheet={{sheet}} as |ContentTag|>
              <ContentTag class="background-aware-content">
                {{#if state.showBackground}}
                  <DSheet.BleedingBackground @sheet={{sheet}} />
                {{/if}}
              </ContentTag>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const content = find(".background-aware-content");

    assert.false(
      content.dataset.dSheet.split(" ").includes("bleeding-background-present"),
      "the absent state keeps Content's default fill"
    );
    assert.strictEqual(
      getComputedStyle(content).backgroundColor,
      "rgb(255, 255, 255)",
      "Content is white without a bleeding background"
    );

    state.showBackground = true;
    await settled();

    assert.true(
      content.dataset.dSheet.split(" ").includes("bleeding-background-present"),
      "the Silk presence token is emitted while the background exists"
    );
    assert.strictEqual(
      getComputedStyle(content).backgroundColor,
      "rgba(0, 0, 0, 0)",
      "the bleeding background owns the fill"
    );
  });

  test("Content contains overscroll only on the resolved swipe-trap axis", async function (assert) {
    await render(
      <template>
        <DSheet.Root @inertOutside={{false}} as |sheet|>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @tracks="left"
          >
            <DSheet.Content @sheet={{sheet}} as |ContentTag|>
              <ContentTag>Content</ContentTag>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const scrollContainer = find("[data-d-sheet~='scroll-container']");
    const style = getComputedStyle(scrollContainer);

    assert.false(
      scrollContainer.dataset.dSheet.split(" ").includes("overscroll-contain"),
      "there is no unconditional vertical containment token"
    );
    assert.strictEqual(
      style.overscrollBehaviorX,
      "contain",
      "the horizontal swipe axis is contained"
    );
    assert.strictEqual(
      style.overscrollBehaviorY,
      "auto",
      "the orthogonal axis retains native overscroll"
    );
  });

  test("centered tracks retain effective overshoot when swipe overshoot is disabled", async function (assert) {
    await render(
      <template>
        <DSheet.Root @inertOutside={{false}} as |sheet|>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @swipeOvershoot={{false}}
            @swipeTrap={{false}}
            @tracks="vertical"
          >
            <DSheet.Content @sheet={{sheet}} as |ContentTag|>
              <ContentTag>Content</ContentTag>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const scrollContainer = find("[data-d-sheet~='scroll-container']");
    const contentWrapper = find("[data-d-sheet~='content-wrapper']");

    assert.false(
      scrollContainer.dataset.dSheet.split(" ").includes("overshoot-inactive"),
      "the centered scroll port does not disable browser overshoot"
    );
    assert.true(
      contentWrapper.dataset.dSheet.split(" ").includes("overshoot-active"),
      "the wrapper reflects the controller's effective overshoot"
    );
    assert.strictEqual(
      getComputedStyle(scrollContainer).overscrollBehaviorY,
      "auto",
      "the centered travel axis retains native overscroll"
    );
  });

  test("Portal does not own Sheet View visibility", async function (assert) {
    const sheet = { isPresented: false };

    await render(
      <template>
        <DSheet.Portal @sheet={{sheet}}>
          <div class="portal-content">Portal content</div>
        </DSheet.Portal>
      </template>
    );

    assert
      .dom(".portal-content")
      .hasText("Portal content", "the portal preserves children while closed");
  });

  test("BleedingBackground delegates animation ownership to Outlet", async function (assert) {
    const presenceChanges = [];
    const registrations = [];
    const cleanups = [];
    const sheet = {
      contentPlacementAttribute: "center",
      isCenteredTrack: true,
      isStackAnimating: false,
      stagingAttribute: "staging-none",
      tracks: "horizontal",
      registerStackingAnimation: (options) => {
        registrations.push({ type: "stacking", options });
        return () => cleanups.push("stacking");
      },
      registerTravelAnimation: (options) => {
        registrations.push({ type: "travel", options });
        return () => cleanups.push("travel");
      },
      setBleedingBackgroundPresent: (present) => {
        presenceChanges.push(present);
      },
    };
    const travelAnimation = {
      opacity: ({ progress }) => progress,
    };
    const stackingAnimation = {
      scale: ({ progress }) => progress,
    };

    await render(
      <template>
        <DSheet.BleedingBackground
          @sheet={{sheet}}
          @travelAnimation={{travelAnimation}}
          @stackingAnimation={{stackingAnimation}}
        >
          Background content
        </DSheet.BleedingBackground>
      </template>
    );

    const background = find("[data-d-sheet~='bleeding-background']");

    assert
      .dom(background)
      .hasAttribute(
        "data-d-sheet",
        /outlet/,
        "the background is also an animation outlet"
      );
    assert
      .dom(background)
      .hasAttribute(
        "data-d-sheet",
        /bleed-disabled/,
        "centered tracks disable background bleed"
      );
    assert
      .dom(background)
      .hasText("Background content", "the background preserves its block");
    assert.deepEqual(
      registrations.map(({ type }) => type).sort(),
      ["stacking", "travel"],
      "both animation types are registered"
    );
    assert.true(
      registrations.every(({ options }) => options.target === background),
      "animations target the bleeding background"
    );
    assert.deepEqual(
      presenceChanges,
      [true],
      "the background registers its presence"
    );

    await clearRender();

    assert.deepEqual(
      cleanups.sort(),
      ["stacking", "travel"],
      "animation registrations are cleaned up"
    );
    assert.deepEqual(
      presenceChanges,
      [true, false],
      "the background unregisters its presence"
    );
  });

  test("Title and Description are semantic animation outlets", async function (assert) {
    const registeredElements = [];
    const animationRegistrations = [];
    const sheet = {
      titleId: "sheet-title",
      descriptionId: "sheet-description",
      registerTitle: (element) => registeredElements.push(element),
      unregisterTitle: () => {},
      registerDescription: (element) => registeredElements.push(element),
      unregisterDescription: () => {},
      registerTravelAnimation: (options) => {
        animationRegistrations.push(options);
        return () => {};
      },
      registerStackingAnimation: () => () => {},
    };
    const travelAnimation = {
      opacity: ({ progress }) => progress,
    };

    await render(
      <template>
        <DSheet.Title @sheet={{sheet}} @travelAnimation={{travelAnimation}}>
          Title
        </DSheet.Title>
        <DSheet.Description
          @sheet={{sheet}}
          @travelAnimation={{travelAnimation}}
        >
          Description
        </DSheet.Description>
      </template>
    );

    assert.dom("h2#sheet-title[data-d-sheet~='outlet']").hasText("Title");
    assert
      .dom("p#sheet-description[data-d-sheet~='outlet']")
      .hasText("Description");
    assert.strictEqual(registeredElements.length, 2, "both elements register");
    assert.strictEqual(
      animationRegistrations.length,
      2,
      "both elements register their travel animation"
    );
  });

  test("centered tracks and overshoot use the mapped geometry", async function (assert) {
    await render(
      <template>
        <div
          class="horizontal-view"
          data-d-sheet="view horizontal"
          hidden
        ></div>
        <div class="vertical-view" data-d-sheet="view vertical" hidden></div>
        <div
          class="left-overshoot"
          data-d-sheet="content-wrapper overshoot-active left"
          style="--d-sheet-travel-size: 100px; --d-sheet-content-travel-axis: 40px; --d-sheet-minimum-snap-distance: 1px; --d-sheet-content-wrapper-overshoot-offset: 10px;"
        ></div>
        <div
          class="right-overshoot"
          data-d-sheet="content-wrapper overshoot-active right"
          style="--d-sheet-travel-size: 100px; --d-sheet-content-travel-axis: 40px; --d-sheet-minimum-snap-distance: 1px; --d-sheet-content-wrapper-overshoot-offset: 10px;"
        ></div>
      </template>
    );

    const horizontalStyle = getComputedStyle(find(".horizontal-view"));
    const verticalStyle = getComputedStyle(find(".vertical-view"));
    const leftOvershootStyle = getComputedStyle(find(".left-overshoot"));
    const rightOvershootStyle = getComputedStyle(find(".right-overshoot"));

    assert.strictEqual(
      horizontalStyle.getPropertyValue("--d-sheet-default-top").trim(),
      "0",
      "the horizontal track starts at the top"
    );
    assert.strictEqual(
      horizontalStyle.getPropertyValue("--d-sheet-default-left").trim(),
      "0",
      "the horizontal track starts at the left"
    );
    assert.strictEqual(
      verticalStyle.getPropertyValue("--d-sheet-default-top").trim(),
      "0",
      "the vertical track starts at the top"
    );
    assert.strictEqual(
      verticalStyle.getPropertyValue("--d-sheet-default-left").trim(),
      "0",
      "the vertical track starts at the left"
    );
    assert.strictEqual(
      leftOvershootStyle.left,
      "59px",
      "left overshoot retains its resting inset"
    );
    assert.strictEqual(
      leftOvershootStyle.right,
      "10px",
      "left overshoot applies the overshoot inset"
    );
    assert.strictEqual(
      rightOvershootStyle.right,
      "59px",
      "right overshoot retains its resting inset"
    );
    assert.strictEqual(
      rightOvershootStyle.left,
      "10px",
      "right overshoot applies the overshoot inset"
    );
  });

  test("centered back spacers retain their measured size", async function (assert) {
    await render(
      <template>
        <div
          class="horizontal-back-spacer"
          data-d-sheet="back-spacer horizontal"
          style="--d-sheet-back-spacer: 73px;"
        ></div>
        <div
          class="vertical-back-spacer"
          data-d-sheet="back-spacer vertical"
          style="--d-sheet-back-spacer: 61px;"
        ></div>
      </template>
    );

    const horizontalStyle = getComputedStyle(find(".horizontal-back-spacer"));
    const verticalStyle = getComputedStyle(find(".vertical-back-spacer"));

    assert.strictEqual(
      horizontalStyle.width,
      "73px",
      "the horizontal spacer uses the measured travel-axis size"
    );
    assert.strictEqual(
      horizontalStyle.height,
      "1px",
      "the horizontal spacer remains one pixel on the cross axis"
    );
    assert.strictEqual(
      verticalStyle.height,
      "61px",
      "the vertical spacer uses the measured travel-axis size"
    );
    assert.strictEqual(
      verticalStyle.width,
      "1px",
      "the vertical spacer remains one pixel on the cross axis"
    );
  });

  test("stack animation suppresses sheet scroll ports without changing snap ownership", async function (assert) {
    await render(
      <template>
        <div data-d-sheet-stack="outlet animating">
          <div
            class="stack-special-wrapper"
            data-d-sheet="scroll-trap-root special-wrapper-root scroll-trap-optimised scroll-horizontal"
          ></div>
          <div
            class="stack-content-scroller"
            data-d-sheet="scroll-container bottom"
          ></div>
        </div>
      </template>
    );

    const wrapperStyle = getComputedStyle(find(".stack-special-wrapper"));
    const scrollerStyle = getComputedStyle(find(".stack-content-scroller"));

    assert.strictEqual(
      wrapperStyle.overflowX,
      "clip",
      "SpecialWrapper scrolling is clipped during stack animation"
    );
    assert.strictEqual(
      scrollerStyle.overflowY,
      "hidden",
      "the main Content scroller is hidden during stack animation"
    );
    assert.strictEqual(
      scrollerStyle.scrollSnapType,
      "y mandatory",
      "animation-state CSS leaves explicit snap disabling to its owner"
    );
  });

  test("secondary scroll traps cover transitions for standalone and stacked sheets", async function (assert) {
    await render(
      <template>
        <div data-d-sheet="view staging-opening">
          <div
            class="standalone-secondary-trap"
            data-d-sheet="scroll-trap-root secondary-scroll-trap no-pointer-events"
          ></div>
        </div>
        <div data-d-sheet="view staging-none">
          <div
            class="idle-secondary-trap"
            data-d-sheet="scroll-trap-root secondary-scroll-trap no-pointer-events"
          ></div>
        </div>
        <div data-d-sheet="view staging-opening">
          <div
            class="pass-through-secondary-trap"
            data-d-sheet="scroll-trap-root secondary-scroll-trap no-pointer-events pass-through"
          ></div>
        </div>
        <div data-d-sheet-stack="outlet animating">
          <div
            class="stack-secondary-trap"
            data-d-sheet="scroll-trap-root secondary-scroll-trap no-pointer-events"
          ></div>
        </div>
      </template>
    );

    const standaloneStyle = getComputedStyle(
      find(".standalone-secondary-trap")
    );
    const idleStyle = getComputedStyle(find(".idle-secondary-trap"));
    const passThroughStyle = getComputedStyle(
      find(".pass-through-secondary-trap")
    );
    const stackStyle = getComputedStyle(find(".stack-secondary-trap"));

    assert.strictEqual(
      standaloneStyle.zIndex,
      "1",
      "standalone staging raises its containment layer"
    );
    assert.strictEqual(
      standaloneStyle.pointerEvents,
      "auto",
      "standalone staging activates the containment layer"
    );
    assert.strictEqual(
      idleStyle.zIndex,
      "-1",
      "an idle standalone sheet leaves the containment layer behind content"
    );
    assert.strictEqual(
      idleStyle.pointerEvents,
      "none",
      "an idle standalone sheet leaves the containment layer inactive"
    );
    assert.strictEqual(
      passThroughStyle.zIndex,
      "-1",
      "pass-through staging leaves the containment layer behind content"
    );
    assert.strictEqual(
      passThroughStyle.pointerEvents,
      "none",
      "pass-through staging leaves outside interactions available"
    );
    assert.strictEqual(
      stackStyle.zIndex,
      "1",
      "stack staging raises the same containment layer"
    );
    assert.strictEqual(
      stackStyle.pointerEvents,
      "auto",
      "stack staging activates the same containment layer"
    );
  });

  test("content wrapper anchoring follows the active vertical track", async function (assert) {
    await render(
      <template>
        <div
          class="top-track-end-placement"
          data-d-sheet="content-wrapper top end"
          style="--d-sheet-travel-size: 100px; --d-sheet-content-travel-axis: 40px; --d-sheet-minimum-snap-distance: 1px;"
        ></div>
        <div
          class="bottom-track-start-placement"
          data-d-sheet="content-wrapper bottom start"
          style="--d-sheet-travel-size: 100px; --d-sheet-content-travel-axis: 40px; --d-sheet-minimum-snap-distance: 1px;"
        ></div>
      </template>
    );

    const topTrackStyle = getComputedStyle(find(".top-track-end-placement"));
    const bottomTrackStyle = getComputedStyle(
      find(".bottom-track-start-placement")
    );

    assert.strictEqual(topTrackStyle.top, "59px", "the top track sets top");
    assert.strictEqual(
      topTrackStyle.alignItems,
      "flex-end",
      "the end placement independently controls alignment"
    );
    assert.strictEqual(
      bottomTrackStyle.bottom,
      "59px",
      "the bottom track sets bottom"
    );
    assert.strictEqual(
      bottomTrackStyle.alignItems,
      "flex-start",
      "the start placement independently controls alignment"
    );
  });

  test("sheet structure does not reset consumer margins", async function (assert) {
    await render(
      <template>
        <div data-d-sheet="content">
          <p class="consumer-content">Consumer content</p>
        </div>
      </template>
    );

    assert.notStrictEqual(
      getComputedStyle(find(".consumer-content")).marginBottom,
      "0px",
      "consumer content keeps its normal block margin"
    );
  });

  test("Backdrop yields its block content", async function (assert) {
    const sheet = createBackdropSheet();

    await render(
      <template>
        <DSheet.Backdrop @sheet={{sheet}}>
          <span class="backdrop-content">Backdrop content</span>
        </DSheet.Backdrop>
      </template>
    );

    assert
      .dom("[data-d-sheet~='backdrop'] .backdrop-content")
      .hasText("Backdrop content", "the backdrop renders its block content");
  });

  test("Backdrop retains its default animation for omitted and null configs", async function (assert) {
    const registrations = [];
    const sheet = createBackdropSheet({
      registerTravelAnimation(options) {
        registrations.push(options);
        return () => {};
      },
    });

    await render(
      <template>
        <DSheet.Backdrop @sheet={{sheet}} class="omitted-animation" />
        <DSheet.Backdrop
          @sheet={{sheet}}
          @travelAnimation={{null}}
          class="null-animation"
        />
      </template>
    );

    assert.strictEqual(
      registrations.length,
      2,
      "both backdrops register a travel animation"
    );

    for (const { config } of registrations) {
      assert.strictEqual(
        typeof config.opacity,
        "function",
        "the default opacity animation is retained"
      );
      assert.strictEqual(
        config.opacity({ progress: 1 }),
        0.33,
        "the default opacity animation is unchanged"
      );
    }
  });

  test("Backdrop keeps its animation registration across equivalent dimming updates", async function (assert) {
    const registrations = [];
    let cleanupCount = 0;
    const state = new (class {
      @tracked themeColorDimming = false;
    })();
    const sheet = createBackdropSheet({
      registerTravelAnimation(options) {
        registrations.push(options);
        return () => cleanupCount++;
      },
    });

    await render(
      <template>
        <DSheet.Backdrop
          @sheet={{sheet}}
          @themeColorDimming={{state.themeColorDimming}}
        />
      </template>
    );

    state.themeColorDimming = undefined;
    await settled();

    assert.strictEqual(
      registrations.length,
      1,
      "the travel animation is not registered again"
    );
    assert.strictEqual(
      cleanupCount,
      0,
      "the existing travel animation remains active"
    );
  });

  test("each Backdrop owns an independent theme-color overlay", async function (assert) {
    const themeColorManager = this.owner.lookup("service:theme-color-manager");
    const overlayUpdates = [];
    const sheet = createBackdropSheet({
      state: { longRunning: { isActive: true } },
    });

    sinon
      .stub(themeColorManager, "getAndStoreUnderlyingThemeColorAsRGBArray")
      .returns(true);
    sinon
      .stub(themeColorManager, "updateThemeColorDimmingOverlay")
      .callsFake((options) => {
        overlayUpdates.push(options);
        return options;
      });
    sinon.stub(themeColorManager, "updateThemeColorDimmingOverlayAlphaValue");
    sinon.stub(themeColorManager, "removeThemeColorDimmingOverlay");
    sinon.stub(capabilities, "isWebKit").value(true);
    sinon
      .stub(capabilities, "isStandaloneWithBlackTranslucent")
      .get(() => false);

    await render(
      <template>
        <DSheet.Backdrop
          @sheet={{sheet}}
          @themeColorDimming="auto"
          class="first-dimming-backdrop"
        />
        <DSheet.Backdrop
          @sheet={{sheet}}
          @themeColorDimming="auto"
          class="second-dimming-backdrop"
        />
      </template>
    );

    assert.strictEqual(overlayUpdates.length, 2, "both overlays register");
    assert.notStrictEqual(
      overlayUpdates[0].dimmingOverlayId,
      overlayUpdates[1].dimmingOverlayId,
      "sibling Backdrops cannot replace each other's overlay"
    );
  });

  test("View applies native focus scroll prevention dynamically", async function (assert) {
    const state = new (class {
      @tracked nativeFocusScrollPrevention;
    })();

    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @nativeFocusScrollPrevention={{state.nativeFocusScrollPrevention}}
          >
            <input aria-label="Focus target" class="sheet-focus-target" />
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    const viewSelector = "[data-d-sheet~='view']";

    assert
      .dom(viewSelector)
      .hasAttribute(
        "data-d-scroll-focus-prevention",
        "true",
        "focus scroll prevention is enabled by default"
      );
    assert.true(
      isInsidePreventionContainer(find(".sheet-focus-target")),
      "focus targets resolve the sheet view as their prevention container"
    );

    state.nativeFocusScrollPrevention = false;
    await settled();

    assert
      .dom(viewSelector)
      .doesNotHaveAttribute(
        "data-d-scroll-focus-prevention",
        "disabling prevention removes the marker"
      );
    assert.false(
      isInsidePreventionContainer(find(".sheet-focus-target")),
      "focus targets stop resolving to an enabled prevention container"
    );

    state.nativeFocusScrollPrevention = true;
    await settled();

    assert
      .dom(viewSelector)
      .hasAttribute(
        "data-d-scroll-focus-prevention",
        "true",
        "re-enabling prevention restores the marker"
      );

    await clearRender();

    assert
      .dom("[data-d-scroll-focus-prevention='true']")
      .doesNotExist("the prevention marker is cleaned up with the view");
  });

  test("View forwards onFocusInside across its focus scope", async function (assert) {
    const focusEvents = [];
    const onFocusInside = (event) => {
      event.changeDefault({ handled: true });
      focusEvents.push(event);
    };

    await render(
      <template>
        <DSheet.Root as |sheet|>
          <DSheet.View
            @sheet={{sheet}}
            @shouldRenderView={{true}}
            @onFocusInside={{onFocusInside}}
          >
            <DSheet.Content @sheet={{sheet}} as |ContentTag|>
              <ContentTag>
                <button class="focus-inside" type="button">Focus me</button>
              </ContentTag>
            </DSheet.Content>
          </DSheet.View>
        </DSheet.Root>
      </template>
    );

    await focus("[data-d-sheet~='view']");
    await focus(".focus-inside");

    assert.strictEqual(
      focusEvents.length,
      2,
      "the callback runs across the entire View"
    );
    assert.strictEqual(
      focusEvents[0].nativeEvent.target,
      find("[data-d-sheet~='view']"),
      "the callback receives focus on the View outside its scroll container"
    );
    assert.strictEqual(
      focusEvents[1].nativeEvent.target,
      find(".focus-inside"),
      "the callback receives the native focus event"
    );
    assert.true(
      focusEvents.every((event) => event.handled),
      "changeDefault updates each behavior event"
    );
  });
});
