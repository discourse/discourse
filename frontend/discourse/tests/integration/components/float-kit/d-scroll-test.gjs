import { fn, hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-scroll", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalResizeObserver = window.ResizeObserver;
    this.originalIntersectionObserver = window.IntersectionObserver;
    this.observedElements = [];
    this.intersectionObservers = [];
    this.originalScrollbarThickness = document.body.style.getPropertyValue(
      "--d-scroll-ua-scrollbar-thickness"
    );

    const observedElements = this.observedElements;

    class MockResizeObserver {
      observe(element) {
        if (!observedElements.includes(element)) {
          observedElements.push(element);
        }
      }

      unobserve(element) {
        const index = observedElements.indexOf(element);
        if (index !== -1) {
          observedElements.splice(index, 1);
        }
      }

      disconnect() {
        observedElements.length = 0;
      }
    }

    window.ResizeObserver = MockResizeObserver;
    globalThis.ResizeObserver = MockResizeObserver;

    const intersectionObservers = this.intersectionObservers;

    class MockIntersectionObserver {
      constructor(callback, options) {
        this.callback = callback;
        this.options = options;
        this.observedElements = [];
        intersectionObservers.push(this);
      }

      observe(element) {
        if (!this.observedElements.includes(element)) {
          this.observedElements.push(element);
        }
      }

      unobserve(element) {
        const index = this.observedElements.indexOf(element);
        if (index !== -1) {
          this.observedElements.splice(index, 1);
        }
      }

      disconnect() {
        this.observedElements.length = 0;
      }
    }

    window.IntersectionObserver = MockIntersectionObserver;
    globalThis.IntersectionObserver = MockIntersectionObserver;
  });

  hooks.afterEach(function () {
    window.ResizeObserver = this.originalResizeObserver;
    globalThis.ResizeObserver = this.originalResizeObserver;
    window.IntersectionObserver = this.originalIntersectionObserver;
    globalThis.IntersectionObserver = this.originalIntersectionObserver;
    if (this.originalScrollbarThickness) {
      document.body.style.setProperty(
        "--d-scroll-ua-scrollbar-thickness",
        this.originalScrollbarThickness
      );
    } else {
      document.body.style.removeProperty("--d-scroll-ua-scrollbar-thickness");
    }
    sinon.restore();
  });

  test("Root renders its structural wrapper and consumer attributes", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root
          class="consumer-scroll-root"
          data-consumer-attribute="forwarded"
          data-d-scroll="consumer-token"
        >
          <span class="scroll-root-child">Content</span>
        </DSheet.Scroll.Root>
      </template>
    );

    assert
      .dom(".consumer-scroll-root")
      .hasAttribute(
        "data-d-scroll",
        /root/,
        "the root exposes its structural token"
      )
      .hasAttribute(
        "data-d-scroll",
        /consumer-token/,
        "the root preserves consumer tokens"
      )
      .hasAttribute(
        "data-consumer-attribute",
        "forwarded",
        "the root forwards consumer attributes"
      );
    assert
      .dom(".consumer-scroll-root > .scroll-root-child")
      .hasText("Content", "the root renders its block content");
  });

  test("Root and View expose distinct structural boundaries", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            data-d-scroll="consumer-view-token"
          >
            <DSheet.Scroll.Content
              @controller={{scroll}}
              data-d-scroll="consumer-content-token"
            >
              Content
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert.dom("[data-d-scroll~='root']").exists({ count: 1 });
    assert.dom("[data-d-scroll~='view']").exists({ count: 1 });
    assert.false(
      /(?:^|\s)root(?:\s|$)/.test(
        find("[data-d-scroll~='view']").dataset.dScroll
      ),
      "the View does not duplicate Root's structural token"
    );
    assert
      .dom("[data-d-scroll~='view']")
      .hasAttribute("data-d-scroll", /consumer-view-token/);
    assert
      .dom("[data-d-scroll~='content']")
      .hasAttribute("data-d-scroll", /consumer-content-token/);
  });

  test("View measures the user-agent scrollbar thickness", async function (assert) {
    document.body.style.removeProperty("--d-scroll-ua-scrollbar-thickness");

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View @controller={{scroll}} @safeArea="none">
            <DSheet.Scroll.Content @controller={{scroll}}>
              Content
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert.true(
      /^\d+px$/.test(
        document.body.style.getPropertyValue(
          "--d-scroll-ua-scrollbar-thickness"
        )
      ),
      "the measured thickness is exposed to scroll ports"
    );
    assert.dom("[data-d-scroll~='scrollbar-measurer']").doesNotExist();
  });

  test("scrollbar shims require a trapped axis without overflow", async function (assert) {
    await render(
      <template>
        <div class="x-trap" data-d-scroll="scroll-container trap-x"></div>
        <div class="y-trap" data-d-scroll="scroll-container trap-y"></div>
        <div
          class="x-trap-with-overflow"
          data-d-scroll="scroll-container trap-x overflow-y"
        ></div>
        <div
          class="y-trap-with-overflow"
          data-d-scroll="scroll-container trap-y overflow-x"
        ></div>
      </template>
    );

    assert.strictEqual(
      getComputedStyle(find(".x-trap")).scrollbarWidth,
      "none",
      "a trapped axis without overflow hides its scrollbar"
    );
    assert.strictEqual(
      getComputedStyle(find(".x-trap-with-overflow")).scrollbarWidth,
      "auto",
      "overflow keeps the native scrollbar behavior"
    );
    assert.strictEqual(
      getComputedStyle(find(".x-trap"), "::before").content,
      '""',
      "an x trap without overflow renders the horizontal shim"
    );
    assert.strictEqual(
      getComputedStyle(find(".y-trap"), "::after").content,
      '""',
      "a y trap without overflow renders the vertical shim"
    );
    assert.strictEqual(
      getComputedStyle(find(".x-trap-with-overflow"), "::before").content,
      "none",
      "overflow on either axis suppresses the horizontal shim"
    );
    assert.strictEqual(
      getComputedStyle(find(".y-trap-with-overflow"), "::after").content,
      "none",
      "overflow on either axis suppresses the vertical shim"
    );
    assert.strictEqual(
      getComputedStyle(find(".x-trap")).overscrollBehaviorX,
      "none",
      "a trapped x axis without overflow prevents gesture propagation"
    );
    assert.strictEqual(
      getComputedStyle(find(".y-trap")).overscrollBehaviorY,
      "none",
      "a trapped y axis without overflow prevents gesture propagation"
    );
    assert.strictEqual(
      getComputedStyle(find(".x-trap")).overflowX,
      "auto",
      "a trapped x axis becomes a gesture-capable scroll container"
    );
    assert.strictEqual(
      getComputedStyle(find(".y-trap")).overflowY,
      "auto",
      "a trapped y axis becomes a gesture-capable scroll container"
    );
  });

  test("sheet animation temporarily disables nested scroll ports", async function (assert) {
    await render(
      <template>
        <div data-d-sheet="outlet animating">
          <div
            class="nested-scroll-port"
            data-d-scroll="scroll-container axis-y"
          ></div>
        </div>
      </template>
    );

    const style = getComputedStyle(find(".nested-scroll-port"));
    assert.strictEqual(
      style.overflowY,
      "hidden",
      "the nested scroll port is disabled during sheet animation"
    );
    assert.strictEqual(
      style.overflowAnchor,
      "none",
      "the nested scroll port does not anchor during sheet animation"
    );
  });

  test("temporarily hidden scrollbars keep their layout space", async function (assert) {
    await render(
      <template>
        <div style="--d-scroll-ua-scrollbar-thickness: 13px;">
          <div data-d-sheet="outlet animating">
            <div
              class="animated-horizontal-scroll-port"
              data-d-scroll="scroll-container axis-x overflow-x"
            ></div>
            <div
              class="animated-horizontal-scroll-port-without-scrollbar"
              data-d-scroll="scroll-container axis-x overflow-x no-scrollbar"
            ></div>
            <div
              class="animated-vertical-scroll-port"
              data-d-scroll="scroll-container axis-y overflow-y"
            ></div>
          </div>
          <div
            class="disabled-horizontal-scroll-port"
            data-d-scroll="scroll-container axis-x overflow-x no-scroll-gesture"
          ></div>
          <div
            class="disabled-vertical-scroll-port"
            data-d-scroll="scroll-container axis-y overflow-y no-scroll-gesture"
          ></div>
          <div
            class="disabled-rtl-scroll-port"
            data-d-scroll="scroll-container axis-y overflow-y no-scroll-gesture"
            dir="rtl"
          ></div>
        </div>
      </template>
    );

    assert.strictEqual(
      getComputedStyle(find(".animated-horizontal-scroll-port")).paddingBottom,
      "13px",
      "sheet animation reserves horizontal scrollbar space"
    );
    assert.strictEqual(
      getComputedStyle(
        find(".animated-horizontal-scroll-port-without-scrollbar")
      ).paddingBottom,
      "0px",
      "animation does not reserve an intentionally hidden horizontal scrollbar"
    );
    assert.strictEqual(
      getComputedStyle(find(".animated-vertical-scroll-port")).paddingRight,
      "13px",
      "sheet animation reserves vertical scrollbar space"
    );
    assert.strictEqual(
      getComputedStyle(find(".disabled-horizontal-scroll-port")).paddingBottom,
      "13px",
      "disabled gestures reserve horizontal scrollbar space"
    );
    assert.strictEqual(
      getComputedStyle(find(".disabled-vertical-scroll-port")).paddingRight,
      "13px",
      "disabled gestures reserve vertical scrollbar space"
    );
    assert.strictEqual(
      getComputedStyle(find(".disabled-rtl-scroll-port")).paddingLeft,
      "13px",
      "vertical scrollbar compensation follows writing direction"
    );
  });

  test("observes the view, content, and spacers for overflow changes", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View @controller={{scroll}}>
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='scroll-container']")
      ),
      "the scroll container is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='content']")
      ),
      "the content is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='start-spacer']")
      ),
      "the start spacer is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='end-spacer']")
      ),
      "the end spacer is observed"
    );
  });

  test("keeps gesture overshoot independent from gesture trapping", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            @scrollGestureOvershoot={{false}}
            @scrollGestureTrap={{false}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='no-overshoot']")
      .exists("overshoot is disabled");
    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-x']")
      .doesNotExist("the x axis remains untrapped");
    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .doesNotExist("the y axis remains untrapped");
    const scrollContainerStyle = getComputedStyle(
      find("[data-d-scroll~='scroll-container']")
    );
    assert.strictEqual(
      scrollContainerStyle.overscrollBehaviorY,
      "none",
      "overshoot is disabled on the scroll axis"
    );
    assert.strictEqual(
      scrollContainerStyle.overscrollBehaviorX,
      "auto",
      "the cross axis keeps its native overshoot behavior"
    );
  });

  test("disables the native scroll gesture outside auto mode", async function (assert) {
    this.scrollGesture = "snap";

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            @scrollGesture={{this.scrollGesture}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert
      .dom(
        "[data-d-scroll~='scroll-container'][data-d-scroll~='no-scroll-gesture']"
      )
      .exists("snap mode disables the native scroll gesture");

    this.set("scrollGesture", "auto");
    await settled();

    assert
      .dom(
        "[data-d-scroll~='scroll-container'][data-d-scroll~='no-scroll-gesture']"
      )
      .doesNotExist("auto mode restores the native scroll gesture");
  });

  test("resolves explicit axis gesture traps independently", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @axis="y"
            @controller={{scroll}}
            @safeArea="none"
            @scrollGestureTrap={{hash x=true y=false}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-x']")
      .exists("the explicit x trap is applied");
    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .doesNotExist("the explicit y value remains untrapped");
  });

  test("updates gesture traps when the view arguments change", async function (assert) {
    this.scrollGestureTrap = false;

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            @scrollGestureTrap={{this.scrollGestureTrap}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .doesNotExist("the initial gesture trap is disabled");

    this.set("scrollGestureTrap", true);
    await settled();

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .exists("the updated gesture trap is enabled");
  });

  test("updates safe-area listener ownership when the arguments change", async function (assert) {
    this.safeArea = "none";
    const addEventListener = sinon.spy(
      window.visualViewport,
      "addEventListener"
    );
    const removeEventListener = sinon.spy(
      window.visualViewport,
      "removeEventListener"
    );

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea={{this.safeArea}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const listenersBeforeSafeArea =
      addEventListener.withArgs("resize").callCount;

    this.set("safeArea", "visual-viewport");
    await settled();

    assert.strictEqual(
      addEventListener.withArgs("resize").callCount,
      listenersBeforeSafeArea + 1,
      "enabling the safe area adds its viewport listener"
    );

    this.set("safeArea", "none");
    await settled();

    assert.true(
      removeEventListener.withArgs("resize").called,
      "disabling the safe area removes its viewport listener"
    );
  });

  test("reconnects asymmetric gesture observers when trap values change", async function (assert) {
    this.scrollGestureTrap = { yStart: false, yEnd: true };

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            @scrollGestureTrap={{this.scrollGestureTrap}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const startSpy = document.querySelector("[data-d-scroll~='spy-start']");
    const endSpy = document.querySelector("[data-d-scroll~='spy-end']");

    this.set("scrollGestureTrap", { yStart: true, yEnd: false });
    await settled();

    const observer = this.intersectionObservers.at(-1);
    assert.true(
      observer.observedElements.includes(startSpy),
      "the replacement observer watches the existing start spy"
    );
    assert.true(
      observer.observedElements.includes(endSpy),
      "the replacement observer watches the existing end spy"
    );

    observer.callback([
      { target: startSpy, isIntersecting: false },
      { target: endSpy, isIntersecting: true },
    ]);
    await settled();

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .doesNotExist("the replacement observer uses the updated start trap");
  });

  test("waits for both gesture spies before treating content as fitting", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @safeArea="none"
            @scrollGestureTrap={{hash yStart=true yEnd=false}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const startSpy = document.querySelector("[data-d-scroll~='spy-start']");
    const observer = this.intersectionObservers.at(-1);

    observer.callback([{ target: startSpy, isIntersecting: true }]);
    await settled();

    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='trap-y']")
      .exists("the unseen end spy is not assumed to be intersecting");
  });

  test("keeps controller configuration in sync with view arguments", async function (assert) {
    this.axis = "y";
    this.pageScroll = false;
    this.safeArea = "visual-viewport";
    this.scrollAnimationSettings = { skip: "auto" };
    this.captureController = (controller) => {
      this.scrollController = controller;
    };

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <span {{didInsert (fn this.captureController scroll)}}></span>
          <DSheet.Scroll.View
            @axis={{this.axis}}
            @controller={{scroll}}
            @pageScroll={{this.pageScroll}}
            @safeArea={{this.safeArea}}
            @scrollAnimationSettings={{this.scrollAnimationSettings}}
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const scrollContainer = document.querySelector(
      "[data-d-scroll~='scroll-container']"
    );
    const scrollCalls = [];
    scrollContainer.scrollTo = (options) => scrollCalls.push(options);

    this.scrollController.scrollTo({
      distance: 10,
      animationSettings: { skip: true },
    });

    assert.deepEqual(
      scrollCalls[0],
      { top: 10, behavior: "instant" },
      "the initial axis configures vertical controller methods"
    );

    this.set("axis", "x");
    await settled();

    this.scrollController.scrollTo({
      distance: 20,
      animationSettings: { skip: true },
    });

    assert.deepEqual(
      scrollCalls[1],
      { left: 20, behavior: "instant" },
      "changing the axis updates controller methods"
    );

    this.set("pageScroll", true);
    this.set("safeArea", "none");
    this.set("scrollAnimationSettings", { skip: false });
    await settled();

    assert.strictEqual(this.scrollController.axis, "x", "the axis updates");
    assert.true(this.scrollController.pageScroll, "page scroll updates");
    assert.strictEqual(
      this.scrollController.safeArea,
      "none",
      "the safe area updates"
    );
    assert.deepEqual(
      this.scrollController.scrollAnimationSettings,
      { skip: false },
      "the animation settings update"
    );
  });

  test("owns the document scroll listener while page scrolling", async function (assert) {
    this.pageScroll = false;
    this.scrollEvents = [];
    this.handleScroll = (event) => this.scrollEvents.push(event);

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            style="height: 100px;"
            @controller={{scroll}}
            @scrollAnchoring={{false}}
            @scrollAnimationSettings={{hash skip=true}}
            @scrollGestureOvershoot={{false}}
            @scrollSnapType="mandatory"
            @onScroll={{this.handleScroll}}
            @pageScroll={{this.pageScroll}}
            @safeArea="none"
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    document.dispatchEvent(new Event("scroll"));
    assert.strictEqual(
      this.scrollEvents.length,
      0,
      "document scrolling is ignored when page scrolling is disabled"
    );

    const initialDocumentStyle = {
      overflowAnchor: getComputedStyle(document.documentElement).overflowAnchor,
      overscrollBehaviorY: getComputedStyle(document.documentElement)
        .overscrollBehaviorY,
      scrollBehavior: getComputedStyle(document.documentElement).scrollBehavior,
      scrollSnapType: getComputedStyle(document.documentElement).scrollSnapType,
    };
    assert.strictEqual(
      getComputedStyle(find("[data-d-scroll~='view']")).height,
      "100px",
      "local scrolling preserves the consumer's view height"
    );

    this.set("pageScroll", true);
    await settled();

    assert
      .dom("[data-d-scroll~='view'][data-d-scroll~='page-scroll']")
      .exists("the view exposes native page-scroll layout state");
    assert
      .dom("[data-d-scroll~='scroll-container'][data-d-scroll~='page-scroll']")
      .exists("the scroll container exposes native page-scroll layout state");
    assert.strictEqual(
      getComputedStyle(
        document.querySelector("[data-d-scroll~='scroll-container']")
      ).overflowY,
      "visible",
      "native page scrolling removes the internal overflow port"
    );
    assert.notStrictEqual(
      getComputedStyle(find("[data-d-scroll~='view']")).height,
      "100px",
      "native page scrolling lets the view grow with its content"
    );
    assert.strictEqual(
      getComputedStyle(
        document.querySelector("[data-d-scroll~='start-spacer']")
      ).width,
      "0px",
      "native page scrolling collapses the safe-area spacer"
    );
    assert.strictEqual(
      getComputedStyle(document.documentElement).overscrollBehaviorY,
      "none",
      "native page scrolling applies overshoot behavior to the page"
    );
    assert.strictEqual(
      getComputedStyle(document.documentElement).scrollBehavior,
      "auto",
      "native page scrolling applies animation behavior to the page"
    );
    assert.strictEqual(
      getComputedStyle(document.documentElement).overflowAnchor,
      "none",
      "native page scrolling applies anchoring behavior to the page"
    );
    assert.strictEqual(
      getComputedStyle(document.documentElement).scrollSnapType,
      "y mandatory",
      "native page scrolling applies snap behavior to the page"
    );

    const pageScrollEvent = new Event("scroll");
    document.dispatchEvent(pageScrollEvent);

    assert.strictEqual(
      this.scrollEvents.length,
      1,
      "document scrolling invokes onScroll once"
    );
    assert.strictEqual(
      this.scrollEvents[0].nativeEvent,
      pageScrollEvent,
      "onScroll receives the document scroll event"
    );

    this.set("pageScroll", false);
    await settled();

    assert
      .dom("[data-d-scroll~='view'][data-d-scroll~='page-scroll']")
      .doesNotExist("disabling page scrolling restores the local layout");
    assert.strictEqual(
      getComputedStyle(
        document.querySelector("[data-d-scroll~='scroll-container']")
      ).overflowY,
      "auto",
      "disabling page scrolling restores the internal overflow port"
    );
    assert.strictEqual(
      getComputedStyle(find("[data-d-scroll~='view']")).height,
      "100px",
      "disabling page scrolling restores the consumer's view height"
    );
    assert.strictEqual(
      getComputedStyle(
        document.querySelector("[data-d-scroll~='start-spacer']")
      ).width,
      "1px",
      "disabling page scrolling restores the safe-area spacer geometry"
    );
    assert.deepEqual(
      {
        overflowAnchor: getComputedStyle(document.documentElement)
          .overflowAnchor,
        overscrollBehaviorY: getComputedStyle(document.documentElement)
          .overscrollBehaviorY,
        scrollBehavior: getComputedStyle(document.documentElement)
          .scrollBehavior,
        scrollSnapType: getComputedStyle(document.documentElement)
          .scrollSnapType,
      },
      initialDocumentStyle,
      "disabling page scrolling restores the document's scroll styles"
    );
    document.dispatchEvent(new Event("scroll"));

    assert.strictEqual(
      this.scrollEvents.length,
      1,
      "disabling page scrolling removes the document listener"
    );
  });

  test("unregisters conditional view and content elements", async function (assert) {
    this.showScroll = true;
    this.captureController = (controller) => {
      this.scrollController = controller;
    };

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <span {{didInsert (fn this.captureController scroll)}}></span>
          {{#if this.showScroll}}
            <DSheet.Scroll.View @controller={{scroll}} @safeArea="none">
              <DSheet.Scroll.Content @controller={{scroll}}>
                <p>Content</p>
              </DSheet.Scroll.Content>
            </DSheet.Scroll.View>
          {{/if}}
        </DSheet.Scroll.Root>
      </template>
    );

    const oldView = this.scrollController.viewElement;
    const oldContent = this.scrollController.contentElement;

    this.set("showScroll", false);
    await settled();

    assert.strictEqual(
      this.scrollController.viewElement,
      null,
      "the removed view is unregistered"
    );
    assert.strictEqual(
      this.scrollController.contentElement,
      null,
      "the removed content is unregistered"
    );
    assert.false(
      this.observedElements.includes(oldView),
      "the removed view is no longer observed"
    );
    assert.false(
      this.observedElements.includes(oldContent),
      "the removed content is no longer observed"
    );

    this.set("showScroll", true);
    await settled();

    assert.notStrictEqual(
      this.scrollController.viewElement,
      oldView,
      "a replacement view is registered"
    );
    assert.notStrictEqual(
      this.scrollController.contentElement,
      oldContent,
      "replacement content is registered"
    );
  });

  test("scroll-start changeDefault updates the event behavior", async function (assert) {
    this.handleScrollStart = (event) => {
      this.scrollStartEvent = event;
      event.changeDefault({ dismissKeyboard: true });
    };

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @onScrollStart={{this.handleScrollStart}}
            @safeArea="none"
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const scrollEvent = new Event("scroll");
    document
      .querySelector("[data-d-scroll~='scroll-container']")
      .dispatchEvent(scrollEvent);

    assert.true(
      this.scrollStartEvent.dismissKeyboard,
      "changeDefault updates the event object"
    );
    assert.strictEqual(
      this.scrollStartEvent.nativeEvent,
      scrollEvent,
      "the behavior event exposes the native scroll event"
    );
  });

  test("focus-inside changeDefault updates the event behavior", async function (assert) {
    this.handleFocusInside = (event) => {
      this.focusInsideEvent = event;
      event.changeDefault({ scrollIntoView: false });
    };

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @nativeFocusScrollPrevention={{false}}
            @onFocusInside={{this.handleFocusInside}}
            @safeArea="none"
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <input data-test-input />
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const focusEvent = new Event("focusin", { bubbles: true });
    document.querySelector("[data-test-input]").dispatchEvent(focusEvent);

    assert.false(
      this.focusInsideEvent.scrollIntoView,
      "changeDefault updates the event object"
    );
    assert.strictEqual(
      this.focusInsideEvent.nativeEvent,
      focusEvent,
      "the behavior event exposes the native focus event"
    );
  });

  test("focus-inside runs for non-text descendants", async function (assert) {
    this.focusEvents = [];
    this.handleFocusInside = (event) => this.focusEvents.push(event);

    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View
            @controller={{scroll}}
            @nativeFocusScrollPrevention={{false}}
            @onFocusInside={{this.handleFocusInside}}
            @safeArea="none"
          >
            <DSheet.Scroll.Content @controller={{scroll}}>
              <button data-test-button type="button">Focus target</button>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    const focusEvent = new Event("focusin", { bubbles: true });
    document.querySelector("[data-test-button]").dispatchEvent(focusEvent);

    assert.strictEqual(
      this.focusEvents.length,
      1,
      "the callback runs for every focused descendant"
    );
    assert.strictEqual(
      this.focusEvents[0].nativeEvent,
      focusEvent,
      "the callback receives the native focus event"
    );
  });

  test("scroll triggers focus before running an action", async function (assert) {
    this.events = [];
    this.action = { type: "scroll-to", distance: 20 };
    this.scrollTo = () => this.events.push("action");
    this.handlePress = () => this.events.push("press");
    this.handleClick = () => this.events.push("click");

    await render(
      <template>
        <DSheet.Scroll.Root>
          <DSheet.Scroll.Trigger
            @action={{this.action}}
            @controller={{hash scrollTo=this.scrollTo}}
            @onClick={{this.handleClick}}
            @onPress={{this.handlePress}}
            class="scroll-trigger"
          >
            Scroll
          </DSheet.Scroll.Trigger>
        </DSheet.Scroll.Root>
      </template>
    );

    const trigger = find(".scroll-trigger");
    trigger.focus = () => this.events.push("focus");
    trigger.click();
    await settled();

    assert.deepEqual(
      this.events,
      ["press", "focus", "action"],
      "a handled action focuses first and does not continue to onClick"
    );
  });
});
