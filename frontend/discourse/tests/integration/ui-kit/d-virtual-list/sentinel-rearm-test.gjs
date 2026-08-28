import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

const SENTINEL = { id: "sentinel", text: "loading" };

function rowsThenSentinel(count) {
  return [
    ...Array.from({ length: count }, (_, index) => ({
      id: index,
      text: `row ${index}`,
    })),
    SENTINEL,
  ];
}

class State {
  @tracked items = rowsThenSentinel(6);
}

// Supplemental coverage for the branch that arms both latches when the count
// moved but neither boundary key did. A list that keeps a persistent sentinel
// row at one end holds both boundary keys stable across a refresh, so nothing
// else re-arms it and its edge callbacks stop for good.
//
// The list SHRINKS here rather than grows. Growing moves the end band away from
// a stationary range, which re-arms through the ordinary retreat path and hides
// the branch under test.
module(
  "Integration | ui-kit | DVirtualList | sentinel re-arm",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("a count change between stable boundary keys re-arms both edges", async function (assert) {
      const state = new State();
      const ends = [];
      const starts = [];
      const onReachEnd = () => ends.push(true);
      const onReachStart = () => starts.push(true);

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 400px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{state.items}}
            @key="id"
            @estimateSize={{estimate}}
            @onReachEnd={{onReachEnd}}
            @onReachStart={{onReachStart}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      // The whole list fits, so the end band is already on screen and fires once.
      // The start edge is suppressed at mount by design, so nothing has fired it.
      assert.strictEqual(ends.length, 1, "the end fires once on mount");
      assert.strictEqual(starts.length, 0, "the start is suppressed at mount");

      // Same first row, same sentinel last row, fewer rows between them. The
      // window never leaves either band, so the retreat path cannot account for
      // any callback that follows.
      state.items = rowsThenSentinel(1);
      await settled();

      assert.strictEqual(
        ends.length,
        2,
        "the end re-arms and fires again for the new list"
      );
      assert.strictEqual(
        starts.length,
        1,
        "and the start re-arms too, since both boundaries are new content"
      );
    });

    test("a refresh that moves neither the count nor the keys arms nothing", async function (assert) {
      const state = new State();
      const ends = [];
      const onReachEnd = () => ends.push(true);

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 400px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{state.items}}
            @key="id"
            @estimateSize={{estimate}}
            @onReachEnd={{onReachEnd}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.strictEqual(ends.length, 1, "the end fires once on mount");

      // A fresh array of equivalent rows: same keys, same count. Re-arming here
      // would answer an edge callback with another edge callback.
      state.items = rowsThenSentinel(6);
      await settled();

      assert.strictEqual(
        ends.length,
        1,
        "an in-place refresh does not re-fire the end"
      );
    });
  }
);
