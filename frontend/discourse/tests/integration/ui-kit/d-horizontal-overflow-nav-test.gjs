import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { resetSiteDirForTesting } from "discourse/lib/text-direction";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { eq } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

const ITEMS = Array.from({ length: 10 }, (_, index) => `Item ${index + 1}`);

class PortalState {
  @tracked show = false;
  @tracked target = null;
}

const LateNavItems = <template>
  {{#if @state.show}}
    {{#in-element @state.target}}
      {{#each @items as |item index|}}
        <li style="flex: 0 0 80px">
          <a
            class={{if (eq index 7) "active"}}
            href="#late-{{item}}"
          >{{item}}</a>
        </li>
      {{/each}}
    {{/in-element}}
  {{/if}}
</template>;

function nextFrame() {
  return new Promise((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))
  );
}

function requireList(assert, selector = "ul.nav-pills") {
  assert.dom(selector).exists({ count: 1 }, "the navigation list renders");
  return find(selector);
}

function requireActive(assert, selector = "a.active") {
  assert
    .dom(selector)
    .exists({ count: 1 }, "the active navigation item renders");
  return find(selector);
}

function stubReducedMotion(matches) {
  return sinon.stub(window, "matchMedia").returns({ matches });
}

async function scrollTo(selector, props) {
  const element = find(selector);
  Object.assign(element, props);
  await triggerEvent(element, "scroll");
}

module("Integration | ui-kit | DHorizontalOverflowNav", function (hooks) {
  setupRenderingTest(hooks);

  let rtlEnabled = false;

  hooks.afterEach(function () {
    if (rtlEnabled) {
      document.documentElement.classList.remove("rtl");
      resetSiteDirForTesting();
      rtlEnabled = false;
    }
  });

  test("overflow strip: preserves the nav and consumer-owned list structure", async function (assert) {
    await render(
      <template>
        <DHorizontalOverflowNav
          class="consumer-attribute"
          data-consumer="yes"
          @ariaLabel="Section navigation"
          @className="consumer-class"
        >
          <li><a href="#one">One</a></li>
        </DHorizontalOverflowNav>
      </template>
    );

    const nav = find("nav.horizontal-overflow-nav");
    const controls = find(
      ".d-overflow-controls.--owned-scroller.horizontal-overflow-nav__controls"
    );
    const list = requireList(assert, "ul.nav-pills.action-list");

    assert
      .dom("nav.horizontal-overflow-nav")
      .hasAttribute("aria-label", "Section navigation", "the nav is outermost");
    assert
      .dom(
        ".d-overflow-controls.--owned-scroller.horizontal-overflow-nav__controls"
      )
      .exists("the nav uses owned overflow controls");
    assert.dom(nav).exists("the navigation landmark renders");
    assert.strictEqual(
      controls.parentElement,
      nav,
      "the overflow controls are directly inside the nav"
    );
    assert.strictEqual(
      list.parentElement,
      controls,
      "the consumer-owned list is directly inside the controls"
    );
    assert.dom(list).hasClass("consumer-class", "@className lands on the list");
    assert
      .dom(list)
      .hasClass(
        "consumer-attribute",
        "the class splattribute lands on the list"
      );
    assert
      .dom(list)
      .hasAttribute(
        "data-consumer",
        "yes",
        "other splattributes land on the list"
      );
    assert
      .dom(".d-overflow-controls__content")
      .doesNotExist("owned mode renders no generated content scroller");
  });

  test("overflow strip: resolves the wrapper fade width to the nav scale", async function (assert) {
    await render(
      <template>
        <DHorizontalOverflowNav @ariaLabel="Fade width navigation">
          <li><a href="#one">One</a></li>
        </DHorizontalOverflowNav>
      </template>
    );

    const controls = find(".horizontal-overflow-nav__controls");
    assert.strictEqual(
      getComputedStyle(controls).getPropertyValue("--fade-width").trim(),
      "1.5em",
      "the wrapper exposes the nav-specific fade width"
    );
  });

  test("overflow strip: fades the physical trailing edge at logical start", async function (assert) {
    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="LTR fade navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a href="#{{item}}">{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    let list = requireList(assert);
    let styles = getComputedStyle(list);
    let maskImage = styles.maskImage || styles.webkitMaskImage;
    assert.true(
      maskImage.startsWith("linear-gradient(to right"),
      "LTR logical start fades the physical right edge"
    );

    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();
    rtlEnabled = true;
    await render(
      <template>
        <div dir="rtl" style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="RTL fade navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a
                  href="#rtl-{{item}}"
                >{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    list = requireList(assert);
    styles = getComputedStyle(list);
    maskImage = styles.maskImage || styles.webkitMaskImage;
    assert.strictEqual(
      getComputedStyle(list).direction,
      "rtl",
      "the list is RTL"
    );
    assert.true(
      maskImage.startsWith("linear-gradient(to left"),
      "RTL logical start fades the physical left edge"
    );
  });

  test("overflow strip: buttons follow the horizontal scroll edges", async function (assert) {
    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="Fitting navigation">
            <li style="flex: 0 0 80px"><a href="#one">One</a></li>
            <li style="flex: 0 0 80px"><a href="#two">Two</a></li>
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn")
      .doesNotExist("a fitting list renders no buttons");

    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="Overflowing navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a href="#{{item}}">{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(
        ".d-overflow-controls__btn.--right.horizontal-overflow-nav__scroll-right"
      )
      .exists("the physical right button appears at the start");
    assert
      .dom(".d-overflow-controls__btn.--left")
      .doesNotExist("the physical left button is absent at the start");

    const list = find("ul.nav-pills");
    await scrollTo("ul.nav-pills", {
      scrollLeft: list.scrollWidth - list.clientWidth,
    });
    await nextFrame();

    assert
      .dom(
        ".d-overflow-controls__btn.--left.horizontal-overflow-nav__scroll-left"
      )
      .exists("the physical left button appears at the end");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist("the physical right button is absent at the end");
  });

  test("overflow strip: a plain click scrolls one viewport", async function (assert) {
    const matchMediaStub = stubReducedMotion(false);
    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="Clickable navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a href="#{{item}}">{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    const list = requireList(assert);
    const button = find(".d-overflow-controls__btn.--right");
    assert.dom(button).exists("the trailing shared button is available");
    let target;
    list.scrollTo = (options) => (target = options);

    await click(button);

    assert.deepEqual(
      target,
      { left: list.clientWidth, behavior: "smooth" },
      "one click requests exactly one measured viewport"
    );
    matchMediaStub.restore();
  });

  test("overflow strip: mouse hold scrolls continuously and swallows its click once", async function (assert) {
    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="Hold navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a href="#{{item}}">{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    const list = requireList(assert);
    const button = find(".d-overflow-controls__btn.--right");
    assert.dom(button).exists("the trailing shared button is available");
    stubPointerCapture(button);

    await triggerEvent(button, "pointerdown", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });
    await nextFrame();

    assert.true(list.scrollLeft > 0, "the hold advances the strip");
    const firstOffset = list.scrollLeft;

    await nextFrame();
    assert.true(
      list.scrollLeft > firstOffset,
      "the hold continues advancing on later frames"
    );

    await triggerEvent(button, "pointerup", {
      button: 0,
      pointerId: 1,
      isPrimary: true,
      pointerType: "mouse",
    });

    let clicks = 0;
    list.scrollTo = () => clicks++;
    await click(button);
    assert.strictEqual(clicks, 0, "the click following a hold is swallowed");

    await click(button);
    assert.strictEqual(clicks, 1, "the next plain click scrolls exactly once");
  });

  test("overflow strip: late portaled items are measured and reveal the active item", async function (assert) {
    const state = new PortalState();

    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav id="late-nav" @ariaLabel="Late navigation" />
        </div>
        <LateNavItems @items={{ITEMS}} @state={{state}} />
      </template>
    );

    const list = find("#late-nav");
    const nativeScrollTo = list.scrollTo.bind(list);
    let revealCalls = 0;
    list.scrollTo = (options) => {
      revealCalls++;
      nativeScrollTo(options);
    };
    state.target = list;
    state.show = true;
    await settled();
    await nextFrame();

    assert
      .dom("#late-nav")
      .hasAttribute(
        "data-d-scroll-overflow",
        "",
        "the list reports overflow after portal insertion"
      );
    assert
      .dom(".d-overflow-controls__btn.--right")
      .exists("the trailing button appears after portal insertion");
    assert.strictEqual(
      revealCalls,
      1,
      "the first late active item is revealed exactly once"
    );
    const active = requireActive(assert, "#late-nav a.active");
    const listRect = list.getBoundingClientRect();
    const activeRect = active.getBoundingClientRect();
    assert.true(list.scrollLeft > 0, "the late active item moves the strip");
    assert.true(
      activeRect.left >= listRect.left - 1,
      "the late active item's leading edge is inside the strip"
    );
    assert.true(
      activeRect.right <= listRect.right + 1,
      "the late active item's trailing edge is inside the strip"
    );
    assert.true(
      Math.abs(
        (activeRect.left + activeRect.right) / 2 -
          (listRect.left + listRect.right) / 2
      ) <= 1,
      "the late active item is centered in the strip"
    );
  });

  test("overflow strip: mount reveal centers the active item without moving the page", async function (assert) {
    const pageScroll = window.scrollY;

    await render(
      <template>
        <div style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="Active navigation">
            {{#each ITEMS as |item index|}}
              <li style="flex: 0 0 80px">
                <a
                  class={{if (eq index 7) "active"}}
                  href="#{{item}}"
                >{{item}}</a>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );

    await nextFrame();

    const list = requireList(assert);
    const active = requireActive(assert);
    assert
      .dom(".d-overflow-controls.--owned-scroller")
      .exists("the active list owns the shared scroller");
    const listRect = list.getBoundingClientRect();
    const activeRect = active.getBoundingClientRect();

    assert.true(list.scrollLeft > 0, "the strip moves toward the active item");
    assert.true(
      activeRect.left >= listRect.left - 1,
      "the active item's leading edge lies inside the strip"
    );
    assert.true(
      activeRect.right <= listRect.right + 1,
      "the active item's trailing edge lies inside the strip"
    );
    assert.true(
      Math.abs(
        (activeRect.left + activeRect.right) / 2 -
          (listRect.left + listRect.right) / 2
      ) <= 1,
      "the active item is centered in the strip"
    );
    assert.strictEqual(window.scrollY, pageScroll, "the page does not move");
  });

  test("overflow strip: RTL maps logical start to the physical left button", async function (assert) {
    const matchMediaStub = stubReducedMotion(false);
    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();
    rtlEnabled = true;

    await render(
      <template>
        <div dir="rtl" style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="RTL navigation">
            {{#each ITEMS as |item|}}
              <li style="flex: 0 0 80px"><a href="#{{item}}">{{item}}</a></li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom(".d-overflow-controls__btn.--left")
      .exists("the physical left button appears at logical start");
    assert
      .dom(".d-overflow-controls__btn.--right")
      .doesNotExist("the physical right button is absent at logical start");

    const list = requireList(assert);
    const button = find(".d-overflow-controls__btn.--left");
    assert.dom(button).exists("the logical trailing button renders");
    assert.strictEqual(
      getComputedStyle(list).direction,
      "rtl",
      "the fixture list resolves to RTL"
    );
    let target;
    list.scrollTo = (options) => (target = options);
    await click(button);

    assert.deepEqual(
      target,
      { left: -list.clientWidth, behavior: "smooth" },
      "the physical left button requests one negative viewport"
    );
    matchMediaStub.restore();
  });

  test("overflow strip: RTL mount reveal keeps the active item inside the list", async function (assert) {
    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();
    rtlEnabled = true;
    const pageScroll = window.scrollY;

    await render(
      <template>
        <div dir="rtl" style="width: 200px">
          <DHorizontalOverflowNav @ariaLabel="RTL active navigation">
            {{#each ITEMS as |item index|}}
              <li style="flex: 0 0 80px">
                <a
                  class={{if (eq index 7) "active"}}
                  href="#{{item}}"
                >{{item}}</a>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      </template>
    );

    await nextFrame();

    const list = requireList(assert);
    const active = requireActive(assert);
    assert
      .dom(".d-overflow-controls.--owned-scroller")
      .exists("the RTL list owns the shared scroller");
    assert.deepEqual(
      {
        direction: getComputedStyle(list).direction,
        overflows: list.scrollWidth > list.clientWidth,
      },
      { direction: "rtl", overflows: true },
      "the fixture is an overflowing RTL scroller"
    );
    const listRect = list.getBoundingClientRect();
    const activeRect = active.getBoundingClientRect();

    assert.true(list.scrollLeft < 0, "the RTL strip uses a negative offset");
    assert.true(
      activeRect.left >= listRect.left - 1,
      "the active item's leading edge lies inside the RTL strip"
    );
    assert.true(
      activeRect.right <= listRect.right + 1,
      "the active item's trailing edge lies inside the RTL strip"
    );
    assert.true(
      Math.abs(
        (activeRect.left + activeRect.right) / 2 -
          (listRect.left + listRect.right) / 2
      ) <= 1,
      "the active item is centered in the RTL strip"
    );
    assert.strictEqual(window.scrollY, pageScroll, "the page does not move");
  });
});
