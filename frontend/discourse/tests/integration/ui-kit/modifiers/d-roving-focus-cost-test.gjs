import { tracked } from "@glimmer/tracking";
import {
  findAll,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

const SMALL_GROUP_SIZE = 128;
const LARGE_GROUP_SIZE = SMALL_GROUP_SIZE * 4;
const SMALL_GROUP_ITEMS = Array.from(
  { length: SMALL_GROUP_SIZE },
  (_, index) => index
);
const LARGE_GROUP_ITEMS = Array.from(
  { length: LARGE_GROUP_SIZE },
  (_, index) => index
);

const NON_BLOCKING_INPUT_TYPES = [
  "checkbox",
  "button",
  "submit",
  "reset",
  "image",
  "file",
];

const BLOCKING_INPUT_TYPES = [
  "text",
  "search",
  "tel",
  "url",
  "email",
  "password",
  "number",
  "radio",
  "range",
  "date",
  "month",
  "week",
  "time",
  "datetime-local",
  "color",
];

function isMeasuredItem(element) {
  return element instanceof HTMLElement && element.matches(".measured-item");
}

async function measureForcedReads(callback) {
  const offsetParentDescriptor = Object.getOwnPropertyDescriptor(
    HTMLElement.prototype,
    "offsetParent"
  );
  const clientRectsDescriptor = Object.getOwnPropertyDescriptor(
    Element.prototype,
    "getClientRects"
  );
  const computedStyleDescriptor = Object.getOwnPropertyDescriptor(
    window,
    "getComputedStyle"
  );

  if (
    !offsetParentDescriptor?.get ||
    !clientRectsDescriptor?.value ||
    !computedStyleDescriptor?.value
  ) {
    throw new Error("The browser layout/style APIs cannot be instrumented");
  }

  const reads = {
    offsetParent: 0,
    clientRects: 0,
    computedStyle: 0,
  };

  let offsetParentInstalled = false;
  let clientRectsInstalled = false;
  let computedStyleInstalled = false;
  try {
    Object.defineProperty(HTMLElement.prototype, "offsetParent", {
      ...offsetParentDescriptor,
      get() {
        if (isMeasuredItem(this)) {
          reads.offsetParent++;
        }
        return offsetParentDescriptor.get.call(this);
      },
    });
    offsetParentInstalled = true;
    Object.defineProperty(Element.prototype, "getClientRects", {
      ...clientRectsDescriptor,
      value(...args) {
        if (isMeasuredItem(this)) {
          reads.clientRects++;
        }
        return clientRectsDescriptor.value.apply(this, args);
      },
    });
    clientRectsInstalled = true;
    Object.defineProperty(window, "getComputedStyle", {
      ...computedStyleDescriptor,
      value(element, ...args) {
        if (isMeasuredItem(element)) {
          reads.computedStyle++;
        }
        return computedStyleDescriptor.value.call(this, element, ...args);
      },
    });
    computedStyleInstalled = true;

    await callback();
  } finally {
    try {
      if (computedStyleInstalled) {
        Object.defineProperty(
          window,
          "getComputedStyle",
          computedStyleDescriptor
        );
      }
    } finally {
      try {
        if (clientRectsInstalled) {
          Object.defineProperty(
            Element.prototype,
            "getClientRects",
            clientRectsDescriptor
          );
        }
      } finally {
        if (offsetParentInstalled) {
          Object.defineProperty(
            HTMLElement.prototype,
            "offsetParent",
            offsetParentDescriptor
          );
        }
      }
    }
  }

  return {
    ...reads,
    total: reads.offsetParent + reads.clientRects + reads.computedStyle,
  };
}

async function measureTabIndexWrites(callback) {
  const tabIndexDescriptor = Object.getOwnPropertyDescriptor(
    HTMLElement.prototype,
    "tabIndex"
  );
  const setAttributeDescriptor = Object.getOwnPropertyDescriptor(
    Element.prototype,
    "setAttribute"
  );

  if (!tabIndexDescriptor?.set || !setAttributeDescriptor?.value) {
    throw new Error("The browser tabindex write APIs cannot be instrumented");
  }

  const writes = {
    property: 0,
    attribute: 0,
  };

  let tabIndexInstalled = false;
  let setAttributeInstalled = false;
  try {
    Object.defineProperty(HTMLElement.prototype, "tabIndex", {
      ...tabIndexDescriptor,
      set(value) {
        if (isMeasuredItem(this)) {
          writes.property++;
        }
        tabIndexDescriptor.set.call(this, value);
      },
    });
    tabIndexInstalled = true;
    Object.defineProperty(Element.prototype, "setAttribute", {
      ...setAttributeDescriptor,
      value(name, ...args) {
        if (isMeasuredItem(this) && String(name).toLowerCase() === "tabindex") {
          writes.attribute++;
        }
        return setAttributeDescriptor.value.call(this, name, ...args);
      },
    });
    setAttributeInstalled = true;

    await callback();
  } finally {
    try {
      if (setAttributeInstalled) {
        Object.defineProperty(
          Element.prototype,
          "setAttribute",
          setAttributeDescriptor
        );
      }
    } finally {
      if (tabIndexInstalled) {
        Object.defineProperty(
          HTMLElement.prototype,
          "tabIndex",
          tabIndexDescriptor
        );
      }
    }
  }

  return {
    ...writes,
    total: writes.property + writes.attribute,
  };
}

function authorItems(generation) {
  return [0, 1, 2, 3].map((index) => ({
    id: `${generation}-${index}`,
    label: `${generation}:${index}`,
    tabindex: index === 2 ? "-1" : "0",
  }));
}

module(
  "Integration | ui-kit | Modifier | dRovingFocus | cost oracle",
  function (hooks) {
    setupRenderingTest(hooks);

    test("rovingCost M5 tabStop=false performs no per-item forced reads on modify", async function (assert) {
      const state = new (class {
        @tracked key = 0;
      })();

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              tabStop=false
              itemsKey=state.key
            }}
          >
            {{#each SMALL_GROUP_ITEMS as |index|}}
              <button class="measured-item" role="option">{{index}}</button>
            {{/each}}
          </div>
        </template>
      );

      const reads = await measureForcedReads(async () => {
        state.key++;
        await settled();
      });

      assert.strictEqual(
        reads.total,
        0,
        `tabStop=false does not inspect item navigability during modify (${JSON.stringify(
          reads
        )})`
      );
    });

    test("rovingCost M5 modify preserves at most one tab stop with author-supplied zeros", async function (assert) {
      const state = new (class {
        @tracked items = authorItems("initial");
      })();

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]" itemsKey=state.items}}
          >
            {{#each state.items key="id" as |item|}}
              <button
                class="author-item"
                data-id={{item.id}}
                role="option"
                tabindex={{item.tabindex}}
              >{{item.label}}</button>
            {{/each}}
          </div>
        </template>
      );

      assert.strictEqual(
        findAll('.author-item[tabindex="0"]').length,
        1,
        "initial modify collapses three author-supplied zeros to one tab stop"
      );

      state.items = authorItems("rerendered");
      await settled();

      assert.strictEqual(
        findAll('.author-item[tabindex="0"]').length,
        1,
        "re-rendered author-supplied zeros are also collapsed to one tab stop"
      );
    });

    test("rovingCost M5 tab-stop seeding keeps established selected current first preference order", async function (assert) {
      await render(
        <template>
          <div
            data-group="established"
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]"}}
          >
            <button role="option">First</button>
            <button aria-current="page" role="option">Current</button>
            <button aria-selected="true" role="option">Selected</button>
            <button class="established" role="option" tabindex="0">
              Established
            </button>
          </div>
          <div
            data-group="selected"
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]"}}
          >
            <button role="option">First</button>
            <button aria-current="page" role="option">Current</button>
            <button aria-selected="true" class="selected" role="option">
              Selected
            </button>
          </div>
          <div
            data-group="current"
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]"}}
          >
            <button role="option">First</button>
            <button aria-current="page" class="current" role="option">
              Current
            </button>
          </div>
          <div
            data-group="first"
            role="listbox"
            {{dRovingFocus itemSelector="[role=option]"}}
          >
            <button class="first" role="option">First</button>
            <button role="option">Second</button>
          </div>
        </template>
      );

      assert
        .dom('[data-group="established"] .established')
        .hasAttribute("tabindex", "0", "an established tab stop wins");
      assert
        .dom('[data-group="selected"] .selected')
        .hasAttribute(
          "tabindex",
          "0",
          "aria-selected wins when no tab stop is established"
        );
      assert
        .dom('[data-group="current"] .current')
        .hasAttribute(
          "tabindex",
          "0",
          "aria-current wins when no established or selected item exists"
        );
      assert
        .dom('[data-group="first"] .first')
        .hasAttribute("tabindex", "0", "the first item is the final fallback");
    });

    test("rovingCost M6 one API step has mounted-count-independent forced-read cost", async function (assert) {
      let smallApi;
      let largeApi;
      const registerSmall = (api) => (smallApi = api);
      const registerLarge = (api) => (largeApi = api);

      await render(
        <template>
          <div
            data-group="small"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onRegisterApi=registerSmall
            }}
          >
            {{#each SMALL_GROUP_ITEMS as |index|}}
              <button class="measured-item" role="option">{{index}}</button>
            {{/each}}
          </div>
          <div
            data-group="large"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onRegisterApi=registerLarge
            }}
          >
            {{#each LARGE_GROUP_ITEMS as |index|}}
              <button class="measured-item" role="option">{{index}}</button>
            {{/each}}
          </div>
        </template>
      );

      assert.true(smallApi.focusIndex(1), "the small-group cursor is seeded");
      const smallReads = await measureForcedReads(() => {
        assert.strictEqual(
          smallApi.focusNext(),
          "moved",
          "one small-group step moves one item"
        );
      });
      assert
        .dom('[data-group="small"] [role="option"]:nth-child(3)')
        .isFocused("the small-group step lands on the adjacent item");

      assert.true(largeApi.focusIndex(1), "the large-group cursor is seeded");
      const largeReads = await measureForcedReads(() => {
        assert.strictEqual(
          largeApi.focusNext(),
          "moved",
          "one large-group step moves the same one-item distance"
        );
      });
      assert
        .dom('[data-group="large"] [role="option"]:nth-child(3)')
        .isFocused("the large-group step lands on the adjacent item");

      assert.true(
        smallReads.total > 0,
        "the small measurement observes a forced read, guarding the comparison oracle itself"
      );
      assert.strictEqual(
        largeReads.total,
        smallReads.total,
        `quadrupling mounted items from ${SMALL_GROUP_SIZE} to ${LARGE_GROUP_SIZE} does not increase forced reads (small=${JSON.stringify(
          smallReads
        )}, large=${JSON.stringify(largeReads)})`
      );
    });

    test("rovingCost M5 one API step has mounted-count-independent tabindex-write cost", async function (assert) {
      let smallApi;
      let largeApi;
      const registerSmall = (api) => (smallApi = api);
      const registerLarge = (api) => (largeApi = api);

      await render(
        <template>
          <div
            data-group="small-writes"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onRegisterApi=registerSmall
            }}
          >
            {{#each SMALL_GROUP_ITEMS as |index|}}
              <button class="measured-item" role="option">{{index}}</button>
            {{/each}}
          </div>
          <div
            data-group="large-writes"
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              onRegisterApi=registerLarge
            }}
          >
            {{#each LARGE_GROUP_ITEMS as |index|}}
              <button class="measured-item" role="option">{{index}}</button>
            {{/each}}
          </div>
        </template>
      );

      assert.true(smallApi.focusIndex(1), "the small-group cursor is seeded");
      const smallWrites = await measureTabIndexWrites(() => {
        assert.strictEqual(
          smallApi.focusNext(),
          "moved",
          "one small-group step moves one item"
        );
      });
      assert
        .dom('[data-group="small-writes"] [role="option"]:nth-child(3)')
        .isFocused("the small-group step lands on the adjacent item");

      assert.true(largeApi.focusIndex(1), "the large-group cursor is seeded");
      const largeWrites = await measureTabIndexWrites(() => {
        assert.strictEqual(
          largeApi.focusNext(),
          "moved",
          "one large-group step moves the same one-item distance"
        );
      });
      assert
        .dom('[data-group="large-writes"] [role="option"]:nth-child(3)')
        .isFocused("the large-group step lands on the adjacent item");

      assert.true(
        smallWrites.total > 0,
        "the small measurement observes a tabindex write, guarding the comparison oracle itself"
      );
      assert.strictEqual(
        largeWrites.total,
        smallWrites.total,
        `quadrupling mounted items from ${SMALL_GROUP_SIZE} to ${LARGE_GROUP_SIZE} does not increase tabindex writes (small=${JSON.stringify(
          smallWrites
        )}, large=${JSON.stringify(largeWrites)})`
      );
    });

    test("rovingCost M5 replacement and repeated steps preserve one tab stop", async function (assert) {
      let api;
      const registerApi = (registeredApi) => (api = registeredApi);
      const state = new (class {
        @tracked items = authorItems("initial-sequence");
      })();

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector="[role=option]"
              itemsKey=state.items
              onRegisterApi=registerApi
            }}
          >
            {{#each state.items key="id" as |item|}}
              <button
                class="replacement-item"
                data-id={{item.id}}
                role="option"
                tabindex={{item.tabindex}}
              >{{item.label}}</button>
            {{/each}}
          </div>
        </template>
      );

      assert.true(api.focusIndex(2), "the old item set establishes a holder");

      state.items = authorItems("replacement-sequence");
      await settled();

      assert.strictEqual(
        findAll('.replacement-item[tabindex="0"]').length,
        1,
        "fresh author-supplied zeros are collapsed after replacement"
      );

      for (const index of [1, 2, 3]) {
        assert.strictEqual(
          api.focusNext(),
          "moved",
          `step ${index} moves within the replacement set`
        );
        assert
          .dom(`[data-id="replacement-sequence-${index}"]`)
          .isFocused(`step ${index} focuses the expected replacement item`);
        assert.strictEqual(
          findAll('.replacement-item[tabindex="0"]').length,
          1,
          `step ${index} leaves exactly one tab stop`
        );
      }
    });

    test("rovingCost M7 arrow navigation proceeds from non-blocking input types", async function (assert) {
      await render(
        <template>
          <div {{dRovingFocus orientation="vertical" itemSelector=".item"}}>
            {{#each NON_BLOCKING_INPUT_TYPES as |type|}}
              <div class="item">
                <input
                  alt={{type}}
                  data-input-type={{type}}
                  src="data:image/gif;base64,R0lGODlhAQABAAAAACw="
                  type={{type}}
                />
              </div>
              <button class="item" data-target-type={{type}}>
                Target for
                {{type}}
              </button>
            {{/each}}
          </div>
        </template>
      );

      for (const type of NON_BLOCKING_INPUT_TYPES) {
        const input = `[data-input-type="${type}"]`;
        await focus(input);
        await triggerKeyEvent(input, "keydown", "ArrowDown");
        assert
          .dom(`[data-target-type="${type}"]`)
          .isFocused(
            `${type} has no native arrow behavior, so navigation proceeds`
          );
      }
    });

    test("rovingCost M7 arrow navigation is blocked by native arrow-consuming input types", async function (assert) {
      await render(
        <template>
          <div {{dRovingFocus orientation="vertical" itemSelector=".item"}}>
            {{#each BLOCKING_INPUT_TYPES as |type|}}
              <div class="item">
                <input data-input-type={{type}} type={{type}} />
              </div>
              <button class="item">Target for {{type}}</button>
            {{/each}}
          </div>
        </template>
      );

      for (const type of BLOCKING_INPUT_TYPES) {
        const input = `[data-input-type="${type}"]`;
        await focus(input);
        await triggerKeyEvent(input, "keydown", "ArrowDown");
        assert
          .dom(input)
          .isFocused(`${type} keeps ArrowDown for its native behavior`);
      }
    });

    test("rovingCost M7 textarea select and contenteditable keep their arrow keys", async function (assert) {
      await render(
        <template>
          <div {{dRovingFocus orientation="vertical" itemSelector=".item"}}>
            <div class="item"><textarea class="textarea"></textarea></div>
            <button class="item">After textarea</button>
            <div class="item">
              <select class="select"><option>Choice</option></select>
            </div>
            <button class="item">After select</button>
            <div class="item">
              <div class="contenteditable" contenteditable="true">Editable</div>
            </div>
            <button class="item">After contenteditable</button>
          </div>
        </template>
      );

      for (const selector of [".textarea", ".select", ".contenteditable"]) {
        await focus(selector);
        await triggerKeyEvent(selector, "keydown", "ArrowDown");
        assert
          .dom(selector)
          .isFocused(`${selector} keeps ArrowDown for its native behavior`);
      }
    });
  }
);
