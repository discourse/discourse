import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { on } from "@ember/modifier";
import {
  click,
  find,
  findAll,
  focus,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { resetSiteDirForTesting } from "discourse/lib/text-direction";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DTabs from "discourse/ui-kit/d-tabs";

/* eslint-disable qunit/no-early-return */

class TabsState {
  @tracked active;
  @tracked items;
  @tracked showExtra = false;

  constructor(active, items = []) {
    this.active = active;
    this.items = items;
  }
}

function requireTabs(assert, expectedCount) {
  const selector = '[role="tab"]';
  const tabs = findAll(selector);

  assert
    .dom(selector)
    .exists(
      { count: expectedCount },
      `the tablist contains the measured ${expectedCount} declared tabs`
    );

  return tabs.length === expectedCount ? tabs : null;
}

function requirePanel(assert) {
  const selector = '[role="tabpanel"]';
  const panel = find(selector);

  assert.dom(selector).exists({ count: 1 }, "one persistent tabpanel renders");

  return panel;
}

function guardMessageMatches(error, patterns) {
  return patterns.every((pattern) => pattern.test(error.message));
}

module("Integration | ui-kit | DTabs", function (hooks) {
  setupRenderingTest(hooks);

  test("renders declared tabs in order and only the active panel content", async function (assert) {
    const ids = ["overview", "activity", "preferences"];
    const labels = ["Overview", "Activity", "Preferences"];
    const widgetLabel = "Profile sections";
    const contents = [
      "Overview content",
      "Activity content",
      "Preferences content",
    ];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label={{widgetLabel}}
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label={{get labels "0"}}>
            <p data-panel-content={{get ids "0"}}>{{get contents "0"}}</p>
          </tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label={{get labels "1"}}>
            <p data-panel-content={{get ids "1"}}>{{get contents "1"}}</p>
          </tabs.Tab>
          <tabs.Tab @id={{get ids "2"}} @label={{get labels "2"}}>
            <p data-panel-content={{get ids "2"}}>{{get contents "2"}}</p>
          </tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    assert.dom(".d-tabs").exists("the widget renders its root");
    assert.dom('[role="tablist"]').exists("the tabs render inside a tablist");
    assert
      .dom('[role="tablist"]')
      .hasAttribute(
        "aria-label",
        widgetLabel,
        "the tablist uses the required accessible name"
      );
    assert
      .dom('[role="tablist"]')
      .doesNotHaveAttribute(
        "aria-orientation",
        "horizontal is the implicit default orientation"
      );
    assert.deepEqual(
      tabs.map((tab) => tab.textContent.trim()),
      labels,
      "button order follows declaration order"
    );
    for (const tab of tabs) {
      assert.strictEqual(tab.tagName, "BUTTON", "each tab is a real button");
      assert.strictEqual(tab.type, "button", "each tab has a non-submit type");
      assert.strictEqual(
        tab.parentElement,
        find('[role="tablist"]'),
        "each tab is directly inside the tablist"
      );
    }

    assert
      .dom(`[data-panel-content="${ids[1]}"]`)
      .hasText(contents[1], "the active tab content renders in the panel");
    assert
      .dom(`[data-panel-content="${ids[0]}"]`)
      .doesNotExist("content before the active tab is absent");
    assert
      .dom(`[data-panel-content="${ids[2]}"]`)
      .doesNotExist("content after the active tab is absent");
  });

  test("preserves mixed static and keyed loop order through insertion and reorder", async function (assert) {
    const staticTabs = [
      { id: "leading", label: "Leading" },
      { id: "trailing", label: "Trailing" },
    ];
    const initialItems = [
      { id: "loop-a", label: "Loop A" },
      { id: "loop-c", label: "Loop C" },
    ];
    const insertedItem = { id: "loop-b", label: "Loop B" };
    const state = new TabsState(staticTabs[0].id, initialItems);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Mixed tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab
            @id={{get staticTabs "0.id"}}
            @label={{get staticTabs "0.label"}}
          >
            {{get staticTabs "0.label"}}
          </tabs.Tab>
          {{#each state.items key="id" as |item|}}
            <tabs.Tab
              @id={{item.id}}
              @label={{item.label}}
            >{{item.label}}</tabs.Tab>
          {{/each}}
          <tabs.Tab
            @id={{get staticTabs "1.id"}}
            @label={{get staticTabs "1.label"}}
          >
            {{get staticTabs "1.label"}}
          </tabs.Tab>
        </DTabs>
      </template>
    );

    let expectedLabels = [
      staticTabs[0].label,
      ...initialItems.map((item) => item.label),
      staticTabs[1].label,
    ];
    let tabs = requireTabs(assert, expectedLabels.length);
    if (!tabs) {
      return;
    }

    assert.deepEqual(
      tabs.map((tab) => tab.textContent.trim()),
      expectedLabels,
      "static and looped declarations share one strip order"
    );

    state.items = [initialItems[0], insertedItem, initialItems[1]];
    await settled();
    expectedLabels = [
      staticTabs[0].label,
      ...state.items.map((item) => item.label),
      staticTabs[1].label,
    ];
    tabs = requireTabs(assert, expectedLabels.length);
    if (!tabs) {
      return;
    }

    assert.deepEqual(
      tabs.map((tab) => tab.textContent.trim()),
      expectedLabels,
      "an inserted loop item takes its mid-list position"
    );

    state.items = [insertedItem, initialItems[1], initialItems[0]];
    await settled();
    expectedLabels = [
      staticTabs[0].label,
      ...state.items.map((item) => item.label),
      staticTabs[1].label,
    ];

    assert.deepEqual(
      findAll('[role="tab"]').map((tab) => tab.textContent.trim()),
      expectedLabels,
      "keyed loop reorder changes the button order"
    );
  });

  test("adds and removes a conditional tab declaration in place", async function (assert) {
    const ids = ["first", "conditional", "last"];
    const labels = ["First", "Conditional", "Last"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Conditional tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label={{get labels "0"}}>First panel</tabs.Tab>
          {{#if state.showExtra}}
            <tabs.Tab @id={{get ids "1"}} @label={{get labels "1"}}>Conditional
              panel</tabs.Tab>
          {{/if}}
          <tabs.Tab @id={{get ids "2"}} @label={{get labels "2"}}>Last panel</tabs.Tab>
        </DTabs>
      </template>
    );

    let tabs = requireTabs(assert, ids.length - 1);
    if (!tabs) {
      return;
    }

    assert.deepEqual(
      tabs.map((tab) => tab.textContent.trim()),
      [labels[0], labels[2]],
      "the false conditional contributes no tab"
    );

    state.showExtra = true;
    await settled();
    tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    assert.deepEqual(
      tabs.map((tab) => tab.textContent.trim()),
      labels,
      "the true conditional inserts at its declaration position"
    );

    state.showExtra = false;
    await settled();
    assert.deepEqual(
      findAll('[role="tab"]').map((tab) => tab.textContent.trim()),
      [labels[0], labels[2]],
      "turning the conditional off removes its tab"
    );
  });

  test("click requests activation without changing controlled selection", async function (assert) {
    const ids = ["alpha", "beta"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Controlled tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Alpha"><span
              data-panel={{get ids "0"}}
            >Alpha panel</span></tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Beta"><span
              data-panel={{get ids "1"}}
            >Beta panel</span></tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const panelBefore = requirePanel(assert);
    if (!tabs || !panelBefore) {
      return;
    }

    await click(tabs[1]);

    assert.true(
      onActivate.calledOnceWithExactly(ids[1]),
      "click requests the clicked id once"
    );
    assert
      .dom(tabs[0])
      .hasAttribute("aria-selected", "true", "selection remains controlled");
    assert
      .dom(tabs[1])
      .hasAttribute(
        "aria-selected",
        "false",
        "the request does not select itself"
      );
    assert
      .dom(`[data-panel="${ids[0]}"]`)
      .exists("the old panel content remains");

    state.active = ids[1];
    await settled();

    assert
      .dom(tabs[0])
      .hasAttribute(
        "aria-selected",
        "false",
        "the former tab becomes unselected"
      );
    assert
      .dom(tabs[1])
      .hasAttribute(
        "aria-selected",
        "true",
        "the new controlled tab becomes selected"
      );
    assert
      .dom(`[data-panel="${ids[0]}"]`)
      .doesNotExist("the former content is removed");
    assert.dom(`[data-panel="${ids[1]}"]`).exists("the new content renders");
    assert.strictEqual(
      find('[role="tabpanel"]'),
      panelBefore,
      "the panel element persists through the controlled swap"
    );
  });

  test("element click activates and preserves consumer click propagation", async function (assert) {
    const ids = ["synthesized"];
    const id = ids[0];
    const onActivate = sinon.spy();
    const consumerClick = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{id}}
          @label="Synthetic click tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab
            data-consumer-tab={{id}}
            @id={{id}}
            @label="Synthetic"
            {{on "click" consumerClick}}
          >
            Synthetic panel
          </tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    tabs[0].click();
    await settled();

    assert.true(
      onActivate.calledOnceWithExactly(id),
      "a detail-zero element click activates exactly once"
    );
    assert.true(
      consumerClick.calledOnce,
      "the consumer click modifier also runs"
    );
    assert.strictEqual(
      consumerClick.firstCall.args[0].detail,
      0,
      "the exercised click is the browser's synthesized detail-zero form"
    );
  });

  test("disabled tabs remain focusable but never activate", async function (assert) {
    const ids = ["enabled", "disabled"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "0"}}
          @label="Disabled tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Enabled">Enabled panel</tabs.Tab>
          <tabs.Tab
            @disabled={{true}}
            @id={{get ids "1"}}
            @label="Disabled"
          >Disabled panel</tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    const disabledTab = tabs[1];
    assert
      .dom(disabledTab)
      .hasAttribute("aria-disabled", "true", "disabled state uses ARIA");
    assert
      .dom(disabledTab)
      .doesNotHaveAttribute("disabled", "the tab is not natively disabled");

    await focus(tabs[0]);
    await triggerKeyEvent(tabs[0], "keydown", "ArrowRight");
    assert
      .dom(disabledTab)
      .isFocused("arrow navigation can focus the disabled tab");

    disabledTab.click();
    await settled();
    assert.true(
      onActivate.notCalled,
      "a real element click does not activate the disabled tab"
    );

    await triggerKeyEvent(disabledTab, "keydown", "Enter");
    assert.true(
      onActivate.notCalled,
      "Enter does not activate the disabled tab"
    );
  });

  test("pairs every tab with the live panel and labels it from the active tab", async function (assert) {
    const ids = ["one", "two", "three"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label="Paired tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}
            <tabs.Tab @id={{id}} @label={{id}}>{{id}}</tabs.Tab>
          {{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const panel = requirePanel(assert);
    if (!tabs || !panel) {
      return;
    }

    assert.notStrictEqual(panel.id, "", "the panel exposes a generated id");
    assert
      .dom(panel)
      .hasAttribute("tabindex", "0", "the panel is keyboard focusable");
    for (const tab of tabs) {
      assert.notStrictEqual(tab.id, "", "each tab exposes a generated id");
      assert
        .dom(tab)
        .hasAttribute(
          "aria-controls",
          panel.id,
          "each tab controls the live panel"
        );
      assert.true(
        ["true", "false"].includes(tab.getAttribute("aria-selected")),
        "each tab has a literal boolean aria-selected value"
      );
    }

    const activeTab = tabs.find(
      (tab) => tab.getAttribute("aria-selected") === "true"
    );
    if (!activeTab) {
      assert
        .dom('[role="tab"][aria-selected="true"]')
        .exists("one live tab is active");
      return;
    }
    assert.strictEqual(
      panel.getAttribute("aria-labelledby"),
      activeTab.id,
      "the live panel is labelled by the live active tab id"
    );
  });

  test("renders an empty labelled panel for undefined and unknown active ids", async function (assert) {
    const ids = ["known-a", "known-b"];
    const label = "Possibly inactive tabs";
    const state = new TabsState(undefined);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label={{label}}
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Known A"><span
              data-active-content
            >Known A panel</span></tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Known B"><span
              data-active-content
            >Known B panel</span></tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const panel = requirePanel(assert);
    if (!tabs || !panel) {
      return;
    }

    assert
      .dom('[role="tab"][aria-selected="true"]')
      .doesNotExist("undefined selects no tab");
    assert.dom(panel).hasText("", "undefined renders no panel content");
    assert
      .dom(panel)
      .hasAttribute(
        "aria-label",
        label,
        "the unowned panel uses the widget label"
      );
    assert
      .dom(panel)
      .doesNotHaveAttribute(
        "aria-labelledby",
        "the unowned panel references no tab"
      );

    state.active = "unknown-id";
    await settled();

    assert
      .dom('[role="tab"][aria-selected="true"]')
      .doesNotExist("an unknown id selects no tab");
    assert.dom(panel).hasText("", "an unknown id renders no panel content");
    assert
      .dom(panel)
      .hasAttribute(
        "aria-label",
        label,
        "the unknown-id panel remains labelled"
      );
  });

  test("suppresses tab ARIA roles when there are zero tabs", async function (assert) {
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs @label="Empty tabs" @onActivate={{onActivate}} />
      </template>
    );

    if (!find(".d-tabs")) {
      assert.dom(".d-tabs").exists("the empty widget still renders its root");
      return;
    }

    assert
      .dom('[role="tablist"]')
      .doesNotExist("an empty list exposes no tablist role");
    assert
      .dom('[role="tabpanel"]')
      .doesNotExist("an empty widget exposes no tabpanel role");
    assert
      .dom(".d-tabs [tabindex]")
      .doesNotExist("an empty widget exposes no panel tab stop");
  });

  test("places tabs only inside the consumer-positioned header Tablist", async function (assert) {
    const ids = ["details", "history"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "0"}}
          @label="Header tabs"
          @onActivate={{onActivate}}
        >
          <:header as |header|>
            <div data-consumer-row>
              <header.Tablist data-consumer-tablist />
              <button data-consumer-controls type="button">Refresh</button>
            </div>
          </:header>
          <:default as |tabs|>
            <tabs.Tab @id={{get ids "0"}} @label="Details">Details panel</tabs.Tab>
            <tabs.Tab @id={{get ids "1"}} @label="History">History panel</tabs.Tab>
          </:default>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const tablist = find("[data-consumer-tablist]");
    if (!tabs || !tablist) {
      assert
        .dom("[data-consumer-tablist]")
        .exists("the yielded Tablist lands in the consumer row");
      return;
    }

    assert.strictEqual(
      tablist.closest(".d-overflow-controls").parentElement,
      find("[data-consumer-row]"),
      "the tablist has consumer-chosen placement"
    );
    assert
      .dom(tablist)
      .hasAttribute(
        "role",
        "tablist",
        "the placed element is the real tablist"
      );
    assert.deepEqual(
      Array.from(tablist.children),
      tabs,
      "the placed tablist contains exactly the declared tab buttons"
    );
    assert.strictEqual(
      find("[data-consumer-controls]").parentElement,
      tablist.closest(".d-overflow-controls").parentElement,
      "consumer controls are siblings of the tablist"
    );
    assert.false(
      tablist.contains(find("[data-consumer-controls]")),
      "consumer controls stay outside the tablist"
    );
  });

  test("rescues focus to the persistent panel when active content changes", async function (assert) {
    const ids = ["editable", "replacement"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Focus rescue tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Editable"><input
              data-panel-input
            /></tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Replacement"><p>Replacement
              panel</p></tabs.Tab>
        </DTabs>
      </template>
    );

    const panel = requirePanel(assert);
    if (!panel || !find("[data-panel-input]")) {
      assert
        .dom("[data-panel-input]")
        .exists("the active content renders its focus target");
      return;
    }

    await focus("[data-panel-input]");
    assert
      .dom("[data-panel-input]")
      .isFocused("focus starts inside outgoing panel content");

    state.active = ids[1];
    await settled();

    assert.strictEqual(
      find('[role="tabpanel"]'),
      panel,
      "the tabpanel element is not recreated"
    );
    assert
      .dom(panel)
      .isFocused("focus lands on the persistent panel after the swap");
    assert.notStrictEqual(
      document.activeElement,
      document.body,
      "focus is not stranded on body"
    );
  });

  test("resets panel scroll position when active content changes", async function (assert) {
    const ids = ["long-a", "long-b"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Scrollable tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Long A"><div
              style="height: 200px;"
            >Long A panel</div></tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Long B"><div
              style="height: 200px;"
            >Long B panel</div></tabs.Tab>
        </DTabs>
      </template>
    );

    const panel = requirePanel(assert);
    if (!panel) {
      return;
    }

    panel.style.height = "20px";
    panel.style.overflowY = "auto";
    panel.scrollTop = panel.scrollHeight;
    assert.true(
      panel.scrollTop > 0,
      "the fixture establishes a non-zero panel scroll offset"
    );

    state.active = ids[1];
    await settled();

    assert.strictEqual(
      panel.scrollTop,
      0,
      "the persistent panel returns to the top after the swap"
    );
  });

  test("uses vertical orientation and Up Down focus movement", async function (assert) {
    const ids = ["north", "middle", "south"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label="Vertical tabs"
          @onActivate={{onActivate}}
          @orientation="vertical"
          as |tabs|
        >
          {{#each ids as |id|}}<tabs.Tab
              @id={{id}}
              @label={{id}}
            >{{id}}</tabs.Tab>{{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    assert
      .dom('[role="tablist"]')
      .hasAttribute(
        "aria-orientation",
        "vertical",
        "the tablist advertises vertical orientation"
      );
    await focus(tabs[1]);
    await triggerKeyEvent(tabs[1], "keydown", "ArrowDown");
    assert.dom(tabs[2]).isFocused("ArrowDown moves to the following tab");
    await triggerKeyEvent(tabs[2], "keydown", "ArrowUp");
    assert.dom(tabs[1]).isFocused("ArrowUp moves to the preceding tab");
    assert.true(
      onActivate.notCalled,
      "vertical arrow movement does not activate"
    );
  });

  test("renders rich label content without recreating it on activation", async function (assert) {
    const ids = ["rich", "plain"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Rich labels"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}}>
            <:label><span data-rich-label><strong>Rich</strong>
                label</span></:label>
            <:default>Rich panel</:default>
          </tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Plain">Plain panel</tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const labelBefore = find("[data-rich-label]");
    if (!tabs || !labelBefore) {
      assert
        .dom("[data-rich-label]")
        .exists("the named label block renders inside a tab");
      return;
    }

    assert.true(
      tabs[0].contains(labelBefore),
      "the arbitrary label content lives inside its button"
    );
    state.active = ids[1];
    await settled();
    assert.strictEqual(
      find("[data-rich-label]"),
      labelBefore,
      "selection changes preserve label subtree identity"
    );
  });

  test("component structural attributes override consumer splattributes", async function (assert) {
    const ids = ["safe-pair"];
    const id = ids[0];
    const suppliedId = "consumer-id";
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{id}}
          @label="Safe splats"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{! eslint-disable ember/template-no-unsupported-role-attributes }}
          <tabs.Tab
            id={{suppliedId}}
            role="link"
            aria-selected="false"
            data-consumer-marker={{id}}
            @id={{id}}
            @label="Safe tab"
          >
            Safe panel
          </tabs.Tab>
          {{! eslint-enable ember/template-no-unsupported-role-attributes }}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const panel = requirePanel(assert);
    if (!tabs || !panel) {
      return;
    }

    const tab = tabs[0];
    assert.notStrictEqual(
      tab.id,
      suppliedId,
      "the consumer id cannot replace the generated id"
    );
    assert
      .dom(tab)
      .hasAttribute(
        "role",
        "tab",
        "the consumer role cannot replace the tab role"
      );
    assert
      .dom(tab)
      .hasAttribute(
        "aria-selected",
        "true",
        "the consumer selection cannot replace component state"
      );
    assert
      .dom(tab)
      .hasAttribute(
        "data-consumer-marker",
        id,
        "safe consumer data attributes still splat"
      );
    assert
      .dom(tab)
      .hasAttribute(
        "aria-controls",
        panel.id,
        "splatting cannot break panel control pairing"
      );
    assert
      .dom(panel)
      .hasAttribute(
        "aria-labelledby",
        tab.id,
        "splatting cannot break panel labelling"
      );
  });

  test("removing active and focused looped tabs preserves selection and focus", async function (assert) {
    const initialItems = [
      { id: "removable-active", label: "Removable active" },
      { id: "fallback", label: "Fallback" },
      { id: "removable-focus", label: "Removable focus" },
    ];
    const state = new TabsState(initialItems[0].id, initialItems);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Removable tabs"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each state.items key="id" as |item|}}
            <tabs.Tab
              data-tab-id={{item.id}}
              @id={{item.id}}
              @label={{item.label}}
            >
              <span data-panel-id={{item.id}}>{{item.label}} panel</span>
            </tabs.Tab>
          {{/each}}
        </DTabs>
      </template>
    );

    let tabs = requireTabs(assert, initialItems.length);
    if (!tabs) {
      return;
    }

    state.items = initialItems.slice(1);
    state.active = initialItems[1].id;
    await settled();

    tabs = requireTabs(assert, state.items.length);
    if (!tabs) {
      return;
    }

    assert
      .dom(`[data-tab-id="${state.active}"]`)
      .hasAttribute(
        "aria-selected",
        "true",
        "the consumer fallback becomes active"
      );
    assert
      .dom(`[data-panel-id="${state.active}"]`)
      .exists("the fallback panel renders after active removal");

    const focusedId = initialItems[2].id;
    await focus(`[data-tab-id="${focusedId}"]`);
    state.items = state.items.filter((item) => item.id !== focusedId);
    await settled();

    tabs = findAll('[role="tab"]');
    assert.true(
      tabs.includes(document.activeElement),
      "focus moves to a remaining tab after focused-tab removal"
    );
    assert.notStrictEqual(
      document.activeElement,
      document.body,
      "focused-tab removal does not strand focus on body"
    );
  });

  test("seeds exactly one roving tab stop on the selected tab", async function (assert) {
    const ids = ["seed-a", "seed-b", "seed-c"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label="Roving seed"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}<tabs.Tab
              @id={{id}}
              @label={{id}}
            >{{id}}</tabs.Tab>{{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    const tabStops = tabs.filter((tab) => tab.tabIndex === 0);
    const selectedTab = tabs.find(
      (tab) => tab.getAttribute("aria-selected") === "true"
    );
    assert.strictEqual(
      tabStops.length,
      1,
      "exactly one tab participates in sequential Tab navigation"
    );
    assert.strictEqual(
      tabStops[0],
      selectedTab,
      "the selected tab seeds the roving tab stop"
    );
    for (const tab of tabs.filter((candidate) => candidate !== selectedTab)) {
      assert.strictEqual(
        tab.tabIndex,
        -1,
        "every unselected tab starts outside sequential Tab navigation"
      );
    }
  });

  test("horizontal arrows move focus without activation and wrap both ends", async function (assert) {
    const ids = ["left", "middle", "right"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label="Horizontal arrows"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}<tabs.Tab
              @id={{id}}
              @label={{id}}
            >{{id}}</tabs.Tab>{{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    await focus(tabs[1]);
    await triggerKeyEvent(tabs[1], "keydown", "ArrowRight");
    assert.dom(tabs[2]).isFocused("ArrowRight advances focus");
    await triggerKeyEvent(tabs[2], "keydown", "ArrowRight");
    assert
      .dom(tabs[0])
      .isFocused("ArrowRight wraps from the measured end to the start");
    await triggerKeyEvent(tabs[0], "keydown", "ArrowLeft");
    assert
      .dom(tabs[2])
      .isFocused("ArrowLeft wraps from the measured start to the end");
    assert
      .dom(tabs[1])
      .hasAttribute(
        "aria-selected",
        "true",
        "focus movement leaves selection unchanged"
      );
    assert.true(
      onActivate.notCalled,
      "arrow focus movement does not request activation"
    );
  });

  test("Home and End move focus to measured strip boundaries", async function (assert) {
    const ids = ["home", "middle", "end"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "1"}}
          @label="Boundary keys"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}<tabs.Tab
              @id={{id}}
              @label={{id}}
            >{{id}}</tabs.Tab>{{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    await focus(tabs[Math.floor(tabs.length / 2)]);
    await triggerKeyEvent(document.activeElement, "keydown", "End");
    assert
      .dom(tabs[tabs.length - 1])
      .isFocused("End focuses the measured last tab");
    await triggerKeyEvent(document.activeElement, "keydown", "Home");
    assert.dom(tabs[0]).isFocused("Home focuses the measured first tab");
    assert.true(
      onActivate.notCalled,
      "boundary movement does not request activation"
    );
  });

  test("Enter and Space activate the focused tab exactly once per key", async function (assert) {
    const ids = ["selected", "focused"];
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{get ids "0"}}
          @label="Keyboard activation"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Selected">Selected panel</tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Focused">Focused panel</tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    await focus(tabs[1]);
    await triggerKeyEvent(tabs[1], "keydown", "Enter");
    assert.true(
      onActivate.calledOnceWithExactly(ids[1]),
      "Enter requests the focused id exactly once"
    );

    onActivate.resetHistory();
    await triggerKeyEvent(tabs[1], "keydown", " ");
    assert.true(
      onActivate.calledOnceWithExactly(ids[1]),
      "Space requests the focused id exactly once"
    );
    assert
      .dom(tabs[0])
      .hasAttribute(
        "aria-selected",
        "true",
        "keyboard requests remain controlled"
      );
    assert
      .dom(tabs[1])
      .hasAttribute(
        "aria-selected",
        "false",
        "focused activation does not self-select"
      );
  });

  test("programmatic active changes reseed the tab stop while focus is outside", async function (assert) {
    const ids = ["program-a", "program-b", "program-c"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <button data-outside type="button">Outside</button>
        <DTabs
          @active={{state.active}}
          @label="Programmatic selection"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}<tabs.Tab
              @id={{id}}
              @label={{id}}
            >{{id}}</tabs.Tab>{{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    await focus("[data-outside]");
    state.active = ids[2];
    await settled();

    assert
      .dom("[data-outside]")
      .isFocused("programmatic selection does not steal outside focus");
    assert.strictEqual(
      tabs.filter((tab) => tab.tabIndex === 0).length,
      1,
      "the strip still has one tab stop"
    );
    assert.strictEqual(
      tabs[2].tabIndex,
      0,
      "the newly selected tab becomes the tab stop"
    );
    assert.strictEqual(
      tabs[0].tabIndex,
      -1,
      "the previously selected tab leaves the Tab order"
    );
  });

  test("rejects duplicate tab ids", async function (assert) {
    const duplicateId = "duplicate";
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [/duplicate.*id|id.*unique/i]),
        "the assertion identifies duplicate ids"
      );
    });

    await render(
      <template>
        <DTabs
          @active={{duplicateId}}
          @label="Duplicate ids"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{! eslint-disable ember/template-no-duplicate-id }}
          <tabs.Tab @id={{duplicateId}} @label="First">First</tabs.Tab>
          <tabs.Tab @id={{duplicateId}} @label="Second">Second</tabs.Tab>
          {{! eslint-enable ember/template-no-duplicate-id }}
        </DTabs>
      </template>
    );
    assert.strictEqual(errors, 1, "duplicate ids raise exactly one assertion");
    resetOnerror();
  });

  test("rejects a tab with both label forms", async function (assert) {
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [/label/i, /either|both|xor/i]),
        "the assertion identifies mutually exclusive labels"
      );
    });

    await render(
      <template>
        <DTabs
          @active="both"
          @label="Invalid labels"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id="both" @label="Argument label">
            <:label><span>Block label</span></:label>
            <:default>Panel</:default>
          </tabs.Tab>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "both label forms raise exactly one assertion"
    );
    resetOnerror();
  });

  test("rejects a tab with no label form", async function (assert) {
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [/label/i, /required|exactly|either/i]),
        "the assertion identifies the missing tab label"
      );
    });

    await render(
      <template>
        <DTabs
          @active="unlabelled"
          @label="Invalid labels"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id="unlabelled">Panel</tabs.Tab>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "a missing tab label raises exactly one assertion"
    );
    resetOnerror();
  });

  test("rejects a missing widget label", async function (assert) {
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [/label/i, /required|missing/i]),
        "the assertion identifies the required widget label"
      );
    });

    await render(
      <template>
        <DTabs @active="tab" @onActivate={{onActivate}} as |tabs|>
          <tabs.Tab @id="tab" @label="Tab">Panel</tabs.Tab>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "a missing widget label raises exactly one assertion"
    );
    resetOnerror();
  });

  test("rejects a missing activation callback", async function (assert) {
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [
          /@?onActivate|activat/i,
          /required|missing/i,
        ]),
        "the assertion identifies the required callback"
      );
    });

    await render(
      <template>
        <DTabs @active="tab" @label="Missing callback" as |tabs|>
          <tabs.Tab @id="tab" @label="Tab">Panel</tabs.Tab>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "a missing activation callback raises exactly one assertion"
    );
    resetOnerror();
  });

  test("rejects a custom header that omits the yielded Tablist", async function (assert) {
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [
          /header|Tablist|tablist/i,
          /required|place|render|missing/i,
        ]),
        "the assertion identifies the missing header Tablist"
      );
    });

    await render(
      <template>
        <DTabs
          @active="tab"
          @label="Missing placed tablist"
          @onActivate={{onActivate}}
        >
          <:header><div>Header without placement</div></:header>
          <:default as |tabs|><tabs.Tab
              @id="tab"
              @label="Tab"
            >Panel</tabs.Tab></:default>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "an omitted header Tablist raises exactly one assertion"
    );
    resetOnerror();
  });

  test("rejects non-tab content in the declaration block", async function (assert) {
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror((error) => {
      errors++;
      assert.true(
        guardMessageMatches(error, [
          /tab|content|declaration/i,
          /only|invalid|unexpected/i,
        ]),
        "the assertion identifies non-tab declaration content"
      );
    });

    await render(
      <template>
        <DTabs
          @active="tab"
          @label="Invalid declaration"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id="tab" @label="Tab">Panel</tabs.Tab>
          <div data-non-tab>Not a tab declaration</div>
        </DTabs>
      </template>
    );
    assert.strictEqual(
      errors,
      1,
      "non-tab declaration content raises exactly one assertion"
    );
    resetOnerror();
  });

  test("a later tab change does not steal focus released before it", async function (assert) {
    const ids = ["editable", "replacement"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <button data-outside type="button">Outside</button>
        <DTabs
          @active={{state.active}}
          @label="Released panel focus"
          @onActivate={{onActivate}}
          as |tabs|
        >
          <tabs.Tab @id={{get ids "0"}} @label="Editable">
            {{#unless state.showExtra}}<input data-panel-input />{{/unless}}
          </tabs.Tab>
          <tabs.Tab @id={{get ids "1"}} @label="Replacement">Replacement panel</tabs.Tab>
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    if (!tabs || !find("[data-panel-input]")) {
      assert
        .dom("[data-panel-input]")
        .exists("the active content renders its measured focus target");
      return;
    }

    await focus("[data-panel-input]");
    state.showExtra = true;
    await settled();
    await focus("[data-outside]");

    state.active = ids[1];
    await settled();

    assert
      .dom("[data-outside]")
      .isFocused("a later content swap preserves focus released outside");
  });

  test("tab ids with whitespace and punctuation keep valid ARIA references", async function (assert) {
    const ids = ["account settings", "a:b.c"];
    const state = new TabsState(ids[0]);
    const onActivate = sinon.spy();

    await render(
      <template>
        <DTabs
          @active={{state.active}}
          @label="Unrestricted tab ids"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#each ids as |id|}}
            <tabs.Tab @id={{id}} @label={{id}}>{{id}}</tabs.Tab>
          {{/each}}
        </DTabs>
      </template>
    );

    const tabs = requireTabs(assert, ids.length);
    const panel = requirePanel(assert);
    if (!tabs || !panel) {
      return;
    }

    for (const tab of tabs) {
      assert.false(
        /\s/.test(tab.id),
        `the generated DOM id for measured tab "${tab.dataset.dTab}" contains no whitespace`
      );
      assert.strictEqual(
        document.getElementById(tab.getAttribute("aria-controls")),
        panel,
        `the measured tab "${tab.dataset.dTab}" controls the live panel`
      );
    }

    const activeTab = tabs.find(
      (tab) => tab.getAttribute("aria-selected") === "true"
    );
    if (!activeTab) {
      assert
        .dom('[role="tab"][aria-selected="true"]')
        .exists("one measured tab is active");
      return;
    }

    assert.strictEqual(
      document.getElementById(panel.getAttribute("aria-labelledby")),
      activeTab,
      "the panel's labelledby IDREF resolves to the live active tab"
    );
  });

  test("alternating declaration branches reusing a tab id do not false-positive the duplicate guard", async function (assert) {
    class BranchState {
      @tracked flip = false;
    }

    const state = new BranchState();
    const onActivate = sinon.spy();
    let errors = 0;
    setupOnerror(() => errors++);

    await render(
      <template>
        <DTabs
          @active="same"
          @label="Alternating declaration"
          @onActivate={{onActivate}}
          as |tabs|
        >
          {{#if state.flip}}
            <tabs.Tab @id="same" @label="One">1</tabs.Tab>
          {{else}}
            <tabs.Tab @id="same" @label="Two">2</tabs.Tab>
          {{/if}}
        </DTabs>
      </template>
    );

    state.flip = true;
    await settled();

    assert.strictEqual(
      errors,
      0,
      "replacing a disconnected declaration raises no duplicate assertion"
    );
    assert
      .dom('[role="tab"]')
      .hasText("One", "the new declaration branch supplies the tab label");
    resetOnerror();
  });

  test("keeps the active tab inside an overflowing strip", async function (assert) {
    const ids = ["one", "two", "three", "four", "five", "six"];
    const state = new TabsState("six");
    const onActivate = (id) => (state.active = id);

    await render(
      <template>
        <div style="width: 160px">
          <DTabs
            @active={{state.active}}
            @label="Overflowing sections"
            @onActivate={{onActivate}}
            as |tabs|
          >
            {{#each ids as |id|}}
              <tabs.Tab @id={{id}} @label="Section {{id}}">Panel
                {{id}}</tabs.Tab>
            {{/each}}
          </DTabs>
        </div>
      </template>
    );

    const tablist = find('[role="tablist"]');
    const tabs = requireTabs(assert, ids.length);
    if (!tablist || !tabs) {
      return;
    }

    assert.true(
      tablist.scrollWidth > tablist.clientWidth,
      "the fixture is narrow enough for the strip to overflow"
    );
    assert.true(
      tablist.scrollLeft > 0,
      "an initially active tab past the edge is scrolled into the strip"
    );
    const lastRect = tabs[5].getBoundingClientRect();
    const listRect = tablist.getBoundingClientRect();
    assert.true(
      lastRect.right <= listRect.right + 1,
      "the active tab's trailing edge lies inside the strip's viewport"
    );
    assert.true(
      lastRect.left >= listRect.left - 1,
      "the active tab's leading edge lies inside the strip's viewport"
    );

    state.active = "one";
    await settled();

    assert.strictEqual(
      tablist.scrollLeft,
      0,
      "activating the first tab scrolls the strip back to its start"
    );
  });

  test("exposes the strip's overflow state for the edge fades", async function (assert) {
    const ids = ["one", "two", "three", "four", "five", "six"];
    const state = new TabsState("one");
    const onActivate = (id) => (state.active = id);
    const nextFrame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );

    await render(
      <template>
        <div style="width: 160px">
          <DTabs
            @active={{state.active}}
            @label="Overflowing sections"
            @onActivate={{onActivate}}
            as |tabs|
          >
            {{#each ids as |id|}}
              <tabs.Tab @id={{id}} @label="Section {{id}}">Panel
                {{id}}</tabs.Tab>
            {{/each}}
          </DTabs>
        </div>
      </template>
    );
    await nextFrame();

    assert
      .dom('[role="tablist"]')
      .hasAttribute("data-d-scroll-overflow", "", "the strip reports overflow");
    assert
      .dom('[role="tablist"]')
      .hasAttribute("data-d-scroll-at-start", "", "it starts at the first tab");
    assert.dom('[role="tablist"]').doesNotHaveAttribute("data-d-scroll-at-end");

    state.active = "six";
    await settled();
    await nextFrame();

    assert
      .dom('[role="tablist"]')
      .hasAttribute(
        "data-d-scroll-at-end",
        "",
        "revealing the last tab rests the strip on its end"
      );
    assert
      .dom('[role="tablist"]')
      .doesNotHaveAttribute("data-d-scroll-at-start");
  });

  test("overflow strip: tab buttons follow the horizontal scroll edges", async function (assert) {
    const ids = Array.from({ length: 10 }, (_, index) => `tab-${index + 1}`);
    const state = new TabsState(ids[0]);
    const onActivate = (id) => (state.active = id);
    const nextFrame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );

    await render(
      <template>
        <div style="width: 200px">
          <DTabs
            @active={{state.active}}
            @label="Overflow controls"
            @onActivate={{onActivate}}
            as |tabs|
          >
            {{#each ids as |id|}}
              <tabs.Tab style="flex: 0 0 80px" @id={{id}} @label={{id}}>Panel
                {{id}}</tabs.Tab>
            {{/each}}
          </DTabs>
        </div>
      </template>
    );
    await nextFrame();

    const tabs = requireTabs(assert, ids.length);
    if (!tabs) {
      return;
    }

    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn.--right")
      .exists("the trailing button appears at the first tab");
    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn.--left")
      .doesNotExist("the leading button is absent at the first tab");

    await click(tabs[tabs.length - 1]);

    await nextFrame();

    assert.strictEqual(
      state.active,
      ids[ids.length - 1],
      "activation is fed back into controlled state"
    );
    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn.--left")
      .exists("the leading button appears at the last tab");
    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn.--right")
      .doesNotExist("the trailing button is absent at the last tab");
  });

  test("overflow strip: a fitting tablist renders no buttons", async function (assert) {
    const ids = ["one", "two"];
    const onActivate = sinon.spy();
    const nextFrame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );

    await render(
      <template>
        <div style="width: 400px">
          <DTabs
            @active={{get ids "0"}}
            @label="Fitting tabs"
            @onActivate={{onActivate}}
            as |tabs|
          >
            {{#each ids as |id|}}
              <tabs.Tab style="flex: 0 0 80px" @id={{id}} @label={{id}}>Panel
                {{id}}</tabs.Tab>
            {{/each}}
          </DTabs>
        </div>
      </template>
    );
    await nextFrame();

    assert.true(
      find('[role="tablist"]').scrollWidth <=
        find('[role="tablist"]').clientWidth,
      "the fixture fits inside its tablist"
    );
    assert
      .dom(".d-tabs__strip-controls.d-overflow-controls.--owned-scroller")
      .exists("the fitting tablist still uses the shared strip wrapper");
    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn")
      .doesNotExist("a fitting tablist renders no edge buttons");
  });

  test("overflow strip: a bounded vertical tablist renders a down button", async function (assert) {
    const ids = Array.from({ length: 6 }, (_, index) => `tab-${index + 1}`);
    const onActivate = sinon.spy();
    const nextFrame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );

    await render(
      <template>
        <DTabs
          @active={{get ids "0"}}
          @label="Vertical overflow"
          @onActivate={{onActivate}}
          @orientation="vertical"
        >
          <:header as |header|>
            <header.Tablist style="height: 120px" />
          </:header>
          <:default as |tabs|>
            {{#each ids as |id|}}
              <tabs.Tab style="flex: 0 0 50px" @id={{id}} @label={{id}}>Panel
                {{id}}</tabs.Tab>
            {{/each}}
          </:default>
        </DTabs>
      </template>
    );
    await nextFrame();

    const tablist = find('[role="tablist"]');
    assert.true(
      tablist.scrollHeight > tablist.clientHeight,
      "the fixture overflows its bounded height"
    );
    assert
      .dom(".d-tabs__strip-controls .d-overflow-controls__btn.--down")
      .exists("the vertical trailing button renders");
  });

  test("overflow strip: RTL reveals the last active tab inside the tablist", async function (assert) {
    const ids = Array.from({ length: 10 }, (_, index) => `tab-${index + 1}`);
    const state = new TabsState(ids[ids.length - 1]);
    const onActivate = (id) => (state.active = id);
    const nextFrame = () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve))
      );
    const pageScroll = window.scrollY;

    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();

    try {
      await render(
        <template>
          <div dir="rtl" style="width: 200px">
            <DTabs
              @active={{state.active}}
              @label="RTL overflow"
              @onActivate={{onActivate}}
              as |tabs|
            >
              {{#each ids as |id|}}
                <tabs.Tab style="flex: 0 0 80px" @id={{id}} @label={{id}}>Panel
                  {{id}}</tabs.Tab>
              {{/each}}
            </DTabs>
          </div>
        </template>
      );

      await nextFrame();

      const tablist = find('[role="tablist"]');
      const active = find('[role="tab"][aria-selected="true"]');
      assert.deepEqual(
        {
          direction: getComputedStyle(tablist).direction,
          overflows: tablist.scrollWidth > tablist.clientWidth,
        },
        { direction: "rtl", overflows: true },
        "the fixture is an overflowing RTL scroller"
      );
      const tablistRect = tablist.getBoundingClientRect();
      const activeRect = active.getBoundingClientRect();

      assert.true(
        tablist.scrollLeft < 0,
        "the RTL tablist uses a negative offset"
      );
      assert.true(
        activeRect.left >= tablistRect.left - 1,
        "the active tab's leading edge lies inside the tablist"
      );
      assert.true(
        activeRect.right <= tablistRect.right + 1,
        "the active tab's trailing edge lies inside the tablist"
      );
      assert.strictEqual(window.scrollY, pageScroll, "the page does not move");
    } finally {
      document.documentElement.classList.remove("rtl");
      resetSiteDirForTesting();
    }
  });
});
