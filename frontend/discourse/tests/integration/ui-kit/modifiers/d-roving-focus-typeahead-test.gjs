import { focus, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";

/**
 * The practice page specifies type-ahead as matching the item whose accessible NAME starts with
 * what was typed, which is why these fixtures deliberately disagree with their own text content.
 */

function pressKey(selector, key, modifiers = {}) {
  const element = document.querySelector(selector);
  const event = new KeyboardEvent("keydown", {
    key,
    bubbles: true,
    cancelable: true,
    ...modifiers,
  });
  element.dispatchEvent(event);
  return event;
}

module(
  "Integration | ui-kit | Modifier | dRovingFocus | type-ahead",
  function (hooks) {
    setupRenderingTest(hooks);

    test("moves the cursor to the next item whose accessible name matches", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Banana">2</button>
            <button class="item c" role="option" aria-label="Cherry">3</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "b");
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "the name is what a reader hears, so it is what they type against"
        );
    });

    test("matching ignores case and diacritics", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Éclair">2</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "e");
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "case folding alone would leave e and E-acute as different letters"
        );
    });

    test("accumulates characters, so a longer query narrows further", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Bar">1</button>
            <button class="item b" role="option" aria-label="Baz">2</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "b");
      pressKey(".b", "a");
      pressKey(".b", "z");
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass("b", "the third character selects between the two matches");
    });

    test("Shift produces a capital rather than being rejected as a chord", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Banana">2</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "B", { shiftKey: true });
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "rejecting every shiftKey event makes capitals untypeable"
        );
    });

    test("a real shortcut is still left to whoever owns it", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Banana">2</button>
          </div>
        </template>
      );

      await focus(".a");
      const event = pressKey(".a", "b", { ctrlKey: true });
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass("a", "Ctrl+B belongs to the page, not to the list");
      assert.false(event.defaultPrevented, "and it is not consumed");
    });

    test("AltGr still types, since it sets both ctrlKey and altKey", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Łódź">2</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "ł", { ctrlKey: true, altKey: true });
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "an ISO layout produces this character with a modifier combination that is not a shortcut"
        );
    });

    test("Space activates on an empty query and extends a started one", async function (assert) {
      const activated = [];
      const onActivate = (item) => activated.push(item.className);

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
              onActivate=onActivate
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Apple pie">
              2
            </button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", " ");
      await settled();
      assert.deepEqual(
        activated,
        ["item a"],
        "with nothing typed, Space is activation"
      );

      pressKey(".a", "a");
      pressKey(".a", "p");
      pressKey(".a", " ");
      pressKey(".a", "p");
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass("b", "mid-query it is a character like any other");
      assert.deepEqual(
        activated,
        ["item a"],
        "and it did not also activate anything"
      );
    });

    test("characters typed into an embedded editable are left alone", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <div class="item b" role="option" aria-label="Banana">
              {{! eslint-disable-next-line ember/template-no-nested-interactive }}
              <input class="inner" type="text" />
            </div>
          </div>
        </template>
      );

      await focus(".inner");
      const event = pressKey(".inner", "b");
      await settled();

      assert.false(
        event.defaultPrevented,
        "the caret owns the character, and the listener element being non-editable is not the question"
      );
    });

    test("the query lapses, so a later character starts a new one", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Banana">2</button>
            <button class="item c" role="option" aria-label="Ab">3</button>
          </div>
        </template>
      );

      await focus(".a");

      // Timestamps rather than a timer, so the lapse is expressed by the events themselves.
      const first = new KeyboardEvent("keydown", {
        key: "b",
        bubbles: true,
        cancelable: true,
      });
      Object.defineProperty(first, "timeStamp", { value: 1000 });
      document.querySelector(".a").dispatchEvent(first);
      await settled();

      const later = new KeyboardEvent("keydown", {
        key: "b",
        bubbles: true,
        cancelable: true,
      });
      Object.defineProperty(later, "timeStamp", { value: 99000 });
      document.activeElement.dispatchEvent(later);
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "a fresh single-character query re-matches rather than searching for bb"
        );
    });

    test("repeating a character walks the items sharing that initial", async function (assert) {
      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Apricot">2</button>
            <button class="item c" role="option" aria-label="Banana">3</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "a");
      await settled();
      assert
        .dom(document.activeElement)
        .hasClass(
          "b",
          "the first press moves to the next item sharing the initial"
        );

      pressKey(".b", "a");
      await settled();
      assert
        .dom(document.activeElement)
        .hasClass(
          "a",
          "a repeated character cycles rather than searching for the literal run"
        );
    });

    test("declines to type-ahead over a windowed group", async function (assert) {
      const warn = sinon.stub(console, "warn");

      await render(
        <template>
          <div
            role="listbox"
            {{dRovingFocus
              orientation="vertical"
              itemSelector=".item"
              typeAhead=true
              logicalCount=500
            }}
          >
            <button class="item a" role="option" aria-label="Apple">1</button>
            <button class="item b" role="option" aria-label="Banana">2</button>
          </div>
        </template>
      );

      await focus(".a");
      pressKey(".a", "b");
      await settled();

      assert
        .dom(document.activeElement)
        .hasClass(
          "a",
          "searching only the mounted rows would answer with a nearer match while a truer one sits off-window"
        );
      assert.true(
        warn.calledWithMatch(/typeAhead/),
        "and says so rather than failing quietly"
      );
    });
  }
);
