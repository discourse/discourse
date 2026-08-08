import { tracked } from "@glimmer/tracking";
import { clearRender, find, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { isInsidePreventionContainer } from "discourse/float-kit/components/d-scroll/focus-scroll-utils";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
        />
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
    assert.notStrictEqual(
      outlet.style.transformOrigin,
      "0px 50%",
      "declarative static styles update with the configuration"
    );

    await clearRender();

    assert.strictEqual(
      outlet.style.transformOrigin,
      "",
      "the modifier removes its declarative static style on destruction"
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
