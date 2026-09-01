import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { find, findAll, focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import StyleguideGroups from "discourse/plugins/styleguide/discourse/components/styleguide-groups";

const GROUPS = [
  { id: "start", title: "Start here", description: "The first group." },
  { id: "data", title: "Data" },
  { id: "states", title: "States" },
];

// Deliberately shares the `start` id with GROUPS, which is legal: ids only have to be unique
// within one manifest.
const OTHER_GROUPS = [{ id: "start", title: "Getting going" }];

const SECTION = { id: "select", category: "molecules" };

module("Integration | Component | <StyleguideGroups />", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the requested group", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom("[data-test-styleguide-group='data']").exists();
    assert.dom("[data-test-styleguide-group='start']").doesNotExist();
  });

  // Unmounting is load-bearing: it is what resets a group's live components. A CSS-hidden
  // variant would leave them running, so absence is asserted rather than invisibility.
  test("an inactive group is not rendered at all", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom(".styleguide-group").exists({ count: 1 });
    assert.dom(".styleguide-groups__body").doesNotIncludeText("start body");
  });

  test("falls back to the first group when none is requested", async function (assert) {
    await render(
      <template>
        <StyleguideGroups @groups={{GROUPS}} @section={{SECTION}} as |Group|>
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom("[data-test-styleguide-group='start']").exists();
  });

  test("falls back to the first group when the id is unknown", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="nope"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert
      .dom("[data-test-styleguide-group='start']")
      .exists("an unrecognised query param still renders a usable page");
  });

  test("the group reads its heading and description from the manifest", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom(".styleguide-group__title").hasText("Start here");
    assert.dom(".styleguide-group__description").hasText("The first group.");
  });

  test("a group without a description renders no description element", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom(".styleguide-group__description").doesNotExist();
  });

  test("the region is labelled by its own heading", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
        </StyleguideGroups>
      </template>
    );

    const labelledBy =
      find(".styleguide-group").getAttribute("aria-labelledby");

    assert.dom(`#${labelledBy}`).hasText("Start here");
    assert.dom(".styleguide-group").hasAttribute("role", "region");
  });

  test("marks only the active pill in the subnav", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert
      .dom("[data-test-styleguide-subnav-link='data']")
      .hasAttribute("aria-current", "page")
      .hasClass("active");

    assert
      .dom("[data-test-styleguide-subnav-link='start']")
      .doesNotHaveAttribute(
        "aria-current",
        "the default group is not current while another is open"
      );
  });

  test("every manifest entry gets a pill, in manifest order", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.deepEqual(
      findAll("[data-test-styleguide-subnav-link]").map(
        (link) => link.dataset.testStyleguideSubnavLink
      ),
      ["start", "data", "states"],
      "the manifest is the single source of order, not the yielded blocks"
    );
  });

  // The whole point of yielding a curried example: a grouped page keeps h1 -> h2 -> h3 without
  // any call site restating the level. Passing the bare component instead would leave the
  // group's own h2 followed by sibling h2s, and nothing else would fail.
  test("the yielded example renders at h3, under the group's h2", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start" as |Example|>
            <Example @title="A thing">demo</Example>
          </Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom("h2.styleguide-group__title").hasText("Start here");
    assert.dom("h3.styleguide-example__title").hasText("A thing");
    assert
      .dom("h2.styleguide-example__title")
      .doesNotExist("the example must not sit at the group's own level");
  });

  // Group ids are unique only within one manifest, so deriving the heading id from `@id` would
  // emit duplicate DOM ids the moment a page carries two sets of groups sharing a name — and
  // `aria-labelledby` on the second region would resolve to the first region's heading.
  test("two sets of groups sharing an id still label their own headings", async function (assert) {
    await render(
      <template>
        <StyleguideGroups @groups={{GROUPS}} @section={{SECTION}} as |Group|>
          <Group @id="start">first body</Group>
        </StyleguideGroups>
        <StyleguideGroups
          @groups={{OTHER_GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          {{! The repeated id is the point of this test, and it is a component argument rather
          than a DOM id attribute — the rendered ids come from a counter. Scoped to this line so
          the rule keeps working for the rest of the file. }}
          {{! eslint-disable-next-line ember/template-no-duplicate-id }}
          <Group @id="start">second body</Group>
        </StyleguideGroups>
      </template>
    );

    const regions = findAll(".styleguide-group");
    assert.strictEqual(regions.length, 2, "both groups rendered");

    const [first, second] = regions.map((region) =>
      region.getAttribute("aria-labelledby")
    );

    assert.notStrictEqual(first, second, "the two headings have different ids");
    assert.dom(`#${first}`).hasText("Start here");
    assert.dom(`#${second}`).hasText("Getting going");
  });

  test("names the sub-navigation landmark", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @ariaLabel="Select examples"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom("nav").hasAttribute("aria-label", "Select examples");
  });

  // Everything below changes the active group AFTER the initial render. Without that, the body
  // swap, the focus recovery and the announcement could all be deleted without a single
  // failure. The `scrollTop()` in the same handler is deliberately NOT claimed here: it
  // early-returns under `isTesting()`, so no test can observe it.
  test("swapping the active group swaps the rendered body", async function (assert) {
    const state = new (class {
      @tracked active = "start";
    })();

    await render(
      <template>
        <StyleguideGroups
          @active={{state.active}}
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.dom("[data-test-styleguide-group='start']").exists();

    state.active = "data";
    await settled();

    assert.dom("[data-test-styleguide-group='data']").exists();
    assert
      .dom("[data-test-styleguide-group='start']")
      .doesNotExist("the outgoing group unmounts rather than hiding");
    assert
      .dom("[data-test-styleguide-subnav-link='data']")
      .hasAttribute("aria-current", "page", "the subnav follows the change");
  });

  test("announces the new group, since nothing else signals the swap", async function (assert) {
    const a11y = getOwner(this).lookup("service:a11y");
    const announced = [];
    // Priority is recorded too: swapping polite for assertive would interrupt a screen reader
    // mid-sentence, and a message-only assertion would not notice.
    a11y.announce = (message, type) => announced.push([message, type]);

    const state = new (class {
      @tracked active = "start";
    })();

    await render(
      <template>
        <StyleguideGroups
          @active={{state.active}}
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.deepEqual(announced, [], "nothing is announced on first render");

    state.active = "data";
    await settled();

    assert.deepEqual(
      announced,
      [["Data", "polite"]],
      "the incoming group's title is announced, politely"
    );
  });

  // The real sequence, not a stand-in for it: focus sits on a control INSIDE the outgoing
  // group, that node unmounts with the group, focus falls to <body>, and only then is it ours
  // to recover.
  test("restores focus when the outgoing group took it down with it", async function (assert) {
    const state = new (class {
      @tracked active = "start";
    })();

    await render(
      <template>
        <StyleguideGroups
          @active={{state.active}}
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start"><button
              id="inside"
              type="button"
            >x</button></Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    await focus("#inside");
    assert.dom("#inside").isFocused("precondition: focus is inside the group");

    state.active = "data";
    await settled();

    assert.dom("[data-test-styleguide-group='data']").isFocused();
  });

  // The other half of the guard. Focus that SURVIVES the swap is not ours to move — taking it
  // would yank the reader out of the subnav they are still using.
  test("leaves surviving focus alone", async function (assert) {
    const state = new (class {
      @tracked active = "start";
    })();

    await render(
      <template>
        <StyleguideGroups
          @active={{state.active}}
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    await focus("[data-test-styleguide-subnav-link='data']");

    state.active = "data";
    await settled();

    assert
      .dom("[data-test-styleguide-subnav-link='data']")
      .isFocused("the pill that was clicked keeps focus");
    assert.dom("[data-test-styleguide-group='data']").isNotFocused();
  });

  // The pills are links, not tabs: each is a real URL so it carries history and opens in a new
  // tab. Tab roles would override the link role and lose that.
  test("the pills are links carrying the group query param", async function (assert) {
    await render(
      <template>
        <StyleguideGroups
          @active="start"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
        </StyleguideGroups>
      </template>
    );

    assert
      .dom("[data-test-styleguide-subnav-link='data']")
      .hasTagName("a")
      .hasAttribute("href", /group=data/);
  });

  // A block whose id is in no manifest entry can never match `activeId`, which only ever holds
  // a manifest id, so it renders nothing at all and the page is a subnav above an empty body.
  // Silent because there is no error state to hit: the group is simply never the active one.
  test("warns about a group id that is in no manifest entry", async function (assert) {
    const stub = sinon.stub(console, "warn");

    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="dat">typo body</Group>
          <Group @id="data">data body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.true(
      stub.calledOnceWithMatch('@id="dat"'),
      "warns once, naming the id that matched nothing"
    );

    stub.restore();
  });

  // Guards the check against the two ways it could be trivially satisfied: warning for every
  // group, or warning for every group that is not the active one. Both would fire here, where
  // `start` and `states` are inactive but perfectly valid.
  test("stays quiet when every group id matches the manifest", async function (assert) {
    const stub = sinon.stub(console, "warn");

    await render(
      <template>
        <StyleguideGroups
          @active="data"
          @groups={{GROUPS}}
          @section={{SECTION}}
          as |Group|
        >
          <Group @id="start">start body</Group>
          <Group @id="data">data body</Group>
          <Group @id="states">states body</Group>
        </StyleguideGroups>
      </template>
    );

    assert.false(
      stub.calledWithMatch("StyleguideGroup"),
      "an inactive but declared group is not a mismatch"
    );

    stub.restore();
  });
});
