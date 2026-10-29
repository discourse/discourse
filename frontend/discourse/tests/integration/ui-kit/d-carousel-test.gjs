import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { click, render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCarousel from "discourse/ui-kit/d-carousel";

class State {
  @tracked items;
  @tracked label;
  @tracked loop = true;

  constructor(items) {
    this.items = items;
  }
}

// Every part placed, each tagged so the tests can target the consumer's own
// attributes as well as the primitive's classes. Each slide also carries an
// input and an editable region for the keyboard tests.
const Demo = <template>
  <DCarousel
    class="demo"
    @label={{@state.label}}
    @loop={{@state.loop}}
    as |carousel|
  >
    <carousel.Track data-test-track>
      {{#each @state.items key="@identity" as |item|}}
        <carousel.Slide data-slide={{item}} @key={{item}}>
          <span class="slide-text">{{item}}</span>
          <input aria-label="Note" class="slide-input" />
          <div class="slide-editable" contenteditable="true"></div>
        </carousel.Slide>
      {{/each}}
    </carousel.Track>
    <carousel.Controls data-test-controls>
      <carousel.Previous @label="Previous" />
      <carousel.Dots data-test-dots>
        {{#each @state.items key="@identity" as |item|}}
          <carousel.Dot
            data-dot={{item}}
            @key={{item}}
            @label={{concat "Go to " item}}
          />
        {{/each}}
      </carousel.Dots>
      <carousel.Counter data-test-counter />
      <carousel.Next @label="Next" />
    </carousel.Controls>
    <span class="state">
      {{carousel.activeKey}}:{{carousel.activeIndex}}:{{carousel.count}}
    </span>
  </DCarousel>
</template>;

const TRACK = ".d-carousel__track";
const PREV = ".d-carousel__nav.--previous";
const NEXT = ".d-carousel__nav.--next";

function slide(key) {
  return `.d-carousel__slide[data-slide='${key}']`;
}

function dot(key) {
  return `.d-carousel__dot[data-dot='${key}']`;
}

module("Integration | ui-kit | DCarousel", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the parts and lands attributes on them", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    assert.dom(".d-carousel.demo").exists("the root takes the consumer class");
    assert
      .dom(`${TRACK}[data-test-track]`)
      .hasAttribute("role", "group")
      .hasAttribute("tabindex", "0")
      .doesNotHaveAttribute("aria-label", "no label was given");
    assert
      .dom(`${TRACK} > .d-carousel__slide`)
      .exists({ count: 3 }, "slides are direct children of the track");
    assert
      .dom(slide("a"))
      .hasClass("--active", "the first slide starts active");
    assert.dom(slide("b")).doesNotHaveClass("--active");
    assert.dom(".d-carousel__controls[data-test-controls]").exists();
    assert
      .dom(PREV)
      .hasAttribute("aria-label", "Previous")
      .hasAttribute("title", "Previous")
      .hasAttribute("type", "button");
    assert.dom(NEXT).hasAttribute("aria-label", "Next");
    assert
      .dom(".d-carousel__dots[data-test-dots] .d-carousel__dot")
      .exists({ count: 3 }, "one dot per slide");
    assert
      .dom(dot("a"))
      .hasClass("--active")
      .hasAttribute("aria-current", "true")
      .hasAttribute("aria-label", "Go to a");
    assert.dom(dot("b")).doesNotHaveAttribute("aria-current");
    assert
      .dom(".d-carousel__counter")
      .doesNotExist("a few slides use dots, not a counter");
    assert.dom(".state").hasText("a:0:3", "the live state is yielded");
  });

  test("names the track from the label", async function (assert) {
    const state = new State(["a", "b"]);
    state.label = "Gallery";

    await render(<template><Demo @state={{state}} /></template>);

    assert.dom(TRACK).hasAttribute("aria-label", "Gallery");
  });

  test("steps and wraps around by default", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await click(NEXT);
    assert.dom(slide("b")).hasClass("--active", "next pages forward");
    assert.dom(dot("b")).hasAttribute("aria-current", "true");
    assert.dom(dot("a")).doesNotHaveAttribute("aria-current");
    assert.dom(".state").hasText("b:1:3");

    await click(NEXT);
    await click(NEXT);
    assert.dom(slide("a")).hasClass("--active", "next wraps to the first");

    await click(PREV);
    assert.dom(slide("c")).hasClass("--active", "previous wraps to the last");
    assert.dom(PREV).isNotDisabled();
    assert.dom(NEXT).isNotDisabled();
  });

  test("clamps at the ends and disables the exhausted step when not looping", async function (assert) {
    const state = new State(["a", "b", "c"]);
    state.loop = false;

    await render(<template><Demo @state={{state}} /></template>);

    assert.dom(PREV).isDisabled("nothing before the first slide");
    assert.dom(NEXT).isNotDisabled();

    await click(NEXT);
    await click(NEXT);
    assert.dom(slide("c")).hasClass("--active");
    assert.dom(NEXT).isDisabled("nothing after the last slide");
    assert.dom(PREV).isNotDisabled();

    await triggerKeyEvent(TRACK, "keydown", "ArrowRight");
    assert
      .dom(slide("c"))
      .hasClass("--active", "the keyboard clamps at the end too");
  });

  test("a dot jumps to its slide", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await click(dot("c"));
    assert.dom(slide("c")).hasClass("--active");
    assert
      .dom(dot("c"))
      .hasClass("--active")
      .hasAttribute("aria-current", "true");
    assert.dom(dot("a")).doesNotHaveClass("--active");
  });

  test("arrow keys page along the reading direction", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await triggerKeyEvent(TRACK, "keydown", "ArrowRight");
    assert.dom(slide("b")).hasClass("--active", "right pages forward");

    await triggerKeyEvent(TRACK, "keydown", "ArrowLeft");
    assert.dom(slide("a")).hasClass("--active", "left pages back");

    await triggerKeyEvent(TRACK, "keydown", "ArrowLeft");
    assert.dom(slide("c")).hasClass("--active", "the keyboard wraps too");
  });

  test("arrow keys follow a right-to-left track", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(
      <template>
        <div dir="rtl"><Demo @state={{state}} /></div>
      </template>
    );

    await triggerKeyEvent(TRACK, "keydown", "ArrowLeft");
    assert.dom(slide("b")).hasClass("--active", "left is forward in RTL");

    await triggerKeyEvent(TRACK, "keydown", "ArrowRight");
    assert.dom(slide("a")).hasClass("--active", "right is back in RTL");
  });

  test("arrow keys inside editable content are left to the caret", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await triggerKeyEvent(".slide-input", "keydown", "ArrowRight");
    assert.dom(slide("a")).hasClass("--active", "an input keeps its arrows");

    await triggerKeyEvent(".slide-editable", "keydown", "ArrowRight");
    assert
      .dom(slide("a"))
      .hasClass("--active", "an editable region keeps its arrows");

    await triggerKeyEvent(".slide-text", "keydown", "ArrowRight");
    assert
      .dom(slide("b"))
      .hasClass("--active", "other slide content still pages");
  });

  test("hides the controls for a single slide", async function (assert) {
    const state = new State(["only"]);

    await render(<template><Demo @state={{state}} /></template>);

    assert.dom(slide("only")).hasClass("--active");
    assert.dom(".d-carousel__controls").doesNotExist("nothing to page between");
    assert.dom(".state").hasText("only:0:1");
  });

  test("swaps the dots for a counter past ten slides", async function (assert) {
    const state = new State(
      Array.from({ length: 12 }, (_, index) => `s${index + 1}`)
    );

    await render(<template><Demo @state={{state}} /></template>);

    assert.dom(".d-carousel__dots").doesNotExist("too many slides for dots");
    assert.dom(".d-carousel__counter[data-test-counter]").hasText("1 / 12");

    await click(NEXT);
    assert.dom(".d-carousel__counter").hasText("2 / 12");
  });

  test("pages in track order after a slide is inserted between two others", async function (assert) {
    const state = new State(["a", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    state.items = ["a", "b", "c"];
    await settled();
    assert.dom(".d-carousel__slide").exists({ count: 3 });

    await click(NEXT);
    assert
      .dom(slide("b"))
      .hasClass("--active", "the inserted slide pages in its visible position");

    await click(NEXT);
    assert.dom(slide("c")).hasClass("--active");
  });

  test("falls back to the first slide when the active one is removed", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await click(dot("c"));
    state.items = ["a", "b"];
    await settled();

    assert.dom(slide("a")).hasClass("--active");
    assert.dom(".state").hasText("a:0:2");
  });

  test("keeps the active slide when another is removed", async function (assert) {
    const state = new State(["a", "b", "c"]);

    await render(<template><Demo @state={{state}} /></template>);

    await click(NEXT);
    state.items = ["a", "b"];
    await settled();

    assert.dom(slide("b")).hasClass("--active");
    assert.dom(".state").hasText("b:1:2");
  });
});
