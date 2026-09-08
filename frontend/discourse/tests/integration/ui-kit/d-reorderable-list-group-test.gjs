import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import {
  click,
  find,
  render,
  resetOnerror,
  settled,
  setupOnerror,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import {
  assertDragReady,
  dropCoordinates,
  INDEX_KEY,
  label,
  noop,
  objectItems,
  renderedItemOrder,
} from "discourse/tests/helpers/ui-kit/reorderable-list-fixtures";
import {
  handleSelector,
  moveItemSelector,
  moveVia,
  moveViaChord,
  openMoveMenu,
  rowSelector,
} from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

module("Integration | ui-kit | DReorderableList | group", function (hooks) {
  setupRenderingTest(hooks);

  test("DReorderableListGroup renders no wrapper around its block", async function (assert) {
    await render(
      <template>
        <DMenus />
        <div id="group-placement">
          <span data-placement="before">Before</span>
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <span
              data-placement="first"
              data-group-context={{if group "present" "missing"}}
            >First</span>
            <span data-placement="last">Last</span>
          </DReorderableListGroup>
          <span data-placement="after">After</span>
        </div>
      </template>
    );

    assert.deepEqual(
      Array.from(find("#group-placement").children).map(
        (element) => element.dataset.placement
      ),
      ["before", "first", "last", "after"],
      "the group inserts no element between its parent and block content"
    );
  });

  test("a group onMove false return vetoes the announcement", async function (assert) {
    const items = trackedArray(objectItems());
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    const moves = [];
    // The group's callback wins over any member's own, so this is the veto the
    // member never sees.
    const groupMove = (move) => {
      moves.push(move);
      return false;
    };

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{groupMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary"
            @items={{items}}
            @key="id"
            @label={{label}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveVia("alpha", "down");

    assert.strictEqual(moves.length, 1, "the group callback still receives it");
    assert.strictEqual(
      announce.callCount,
      0,
      "a move the group vetoed is not announced"
    );
  });

  test("DReorderableList requires listId when it joins a group", async function (assert) {
    const items = objectItems().slice(0, 1);
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @items={{items}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );
    } finally {
      resetOnerror();
    }

    assert.true(
      /Assertion Failed:.*(list.?id|required|group)/i.test(
        raised?.message ?? ""
      ),
      "a grouped member without listId triggers a development assertion"
    );
  });

  test("a member re-registering during a re-render keeps its place in the group", async function (assert) {
    const outer = objectItems().slice(0, 1);
    const inner = objectItems().slice(0, 2);
    const state = new (class {
      @tracked frozen = false;
    })();
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            {{! The member sits inside another list's row, which is what makes
                this reachable: freezing the outer list swaps its row branch, so
                the replacement member is constructed before the old one is torn
                down and both briefly claim the same listId. }}
            <DReorderableList
              @items={{outer}}
              @key="id"
              @label={{label}}
              @onMove={{noop}}
              @disabled={{state.frozen}}
            >
              <:row as |section|>
                <DReorderableList
                  @group={{group}}
                  @listId={{section.id}}
                  @items={{inner}}
                  @key="id"
                  @label={{label}}
                >
                  <:row as |item|>
                    <span data-test-item={{item.id}}>{{item.name}}</span>
                  </:row>
                </DReorderableList>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      state.frozen = true;
      await settled();
      state.frozen = false;
      await settled();
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "re-registering the same listId is churn, not a duplicate, so it raises nothing"
    );
    assert
      .dom("[data-test-item]")
      .exists(
        { count: 2 },
        "and the member is still rendering its rows afterwards"
      );
  });

  test("DReorderableList routes an in-list menu move through the group", async function (assert) {
    const primaryItems = objectItems();
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[1];
    const fromIndex = primaryItems.indexOf(movedItem);
    const toIndex = fromIndex - 1;
    const proposed = [...primaryItems];
    proposed.splice(fromIndex, 1);
    proposed.splice(toIndex, 0, movedItem);
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary links"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="button-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="button-secondary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia(movedItem.id, "up", "#button-primary-list");
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "the grouped menu move raises no error"
    );

    assert.strictEqual(
      onMove.callCount,
      1,
      "one member menu move calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "menu",
        item: movedItem,
        fromList: "primary",
        toList: "primary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: primaryItems,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the grouped menu path keeps the standalone payload shape with member IDs"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "the button payload carries the live member items reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].proposedFromItems,
      onMove.firstCall.args[0].proposedToItems,
      "an in-list grouped button move shares one proposed array"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the grouped button move announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position ${toIndex + 1} of ${proposed.length}`,
      "an in-list grouped button move uses the standard announcement"
    );
  });

  test("DReorderableList routes an in-list drag move through the group", async function (assert) {
    const primaryItems = objectItems();
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[2];
    const targetItem = primaryItems[0];
    const fromIndex = primaryItems.indexOf(movedItem);
    const targetIndex = primaryItems.indexOf(targetItem);
    const toIndex = targetIndex + 1;
    const proposed = [...primaryItems];
    proposed.splice(fromIndex, 1);
    proposed.splice(toIndex, 0, movedItem);
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="drag-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="secondary"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
              id="drag-secondary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector(movedItem.id, "#drag-primary-list");
      const target = rowSelector(targetItem.id, "#drag-primary-list");
      assertDragReady(assert, source, target);
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "after"),
      });
    } finally {
      resetOnerror();
    }

    assert.strictEqual(
      raised,
      undefined,
      "the grouped drag move raises no error"
    );

    assert.strictEqual(
      onMove.callCount,
      1,
      "one member drag calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "primary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: primaryItems,
        proposedFromItems: proposed,
        proposedToItems: proposed,
      },
      "the grouped drag path keeps the standalone payload shape with member IDs"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "the drag payload carries the live member items reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].proposedFromItems,
      onMove.firstCall.args[0].proposedToItems,
      "an in-list grouped drag shares one proposed array"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the grouped in-list drag announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position ${toIndex + 1} of ${proposed.length}`,
      "an in-list grouped drag uses the standard announcement"
    );
  });

  test("DReorderableList commits a cross-list drag with frozen source slots", async function (assert) {
    const primaryItems = [
      { id: "primary-alpha", name: "Primary Alpha" },
      { id: "primary-fixed", name: "Primary Fixed" },
      { id: "primary-charlie", name: "Primary Charlie" },
    ];
    const secondaryItems = [
      { id: "secondary-alpha", name: "Secondary Alpha" },
      { id: "secondary-bravo", name: "Secondary Bravo" },
    ];
    const movedItem = primaryItems[0];
    const frozenItem = primaryItems[1];
    const targetItem = secondaryItems[0];
    const movable = (item) => item !== frozenItem;
    const proposedFromItems = [primaryItems[2], frozenItem];
    const proposedToItems = [secondaryItems[0], movedItem, secondaryItems[1]];
    const fromIndex = primaryItems.indexOf(movedItem);
    const toIndex = secondaryItems.indexOf(targetItem) + 1;
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary links"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            @movable={{movable}}
            id="cross-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @listLabel="Secondary links"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="cross-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#cross-primary-list");
    const target = rowSelector(targetItem.id, "#cross-secondary-list");
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "after"),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "one cross-list drop calls the group callback exactly once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "secondary",
        fromIndex,
        toIndex,
        fromItems: primaryItems,
        toItems: secondaryItems,
        proposedFromItems,
        proposedToItems,
      },
      "the cross-list drop reports both lists and their independent proposals"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].fromItems,
      primaryItems,
      "fromItems is the live source array reference"
    );
    assert.strictEqual(
      onMove.firstCall.args[0].toItems,
      secondaryItems,
      "toItems is the live destination array reference"
    );
    assert.deepEqual(
      onMove.firstCall.args[0].proposedFromItems,
      proposedFromItems,
      "removal refills movable source slots while the frozen row keeps index one"
    );
    assert.deepEqual(
      onMove.firstCall.args[0].proposedToItems,
      proposedToItems,
      "an after drop inserts after the destination row without same-list correction"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the cross-list move announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to Secondary links, position ${toIndex + 1} of ${proposedToItems.length}`,
      "the cross-list announcement names the labelled destination list"
    );
  });

  test("DReorderableList keeps step boundaries within each group member", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [
      { id: "secondary-alpha", name: "Secondary Alpha" },
      { id: "secondary-bravo", name: "Secondary Bravo" },
    ];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="boundary-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await openMoveMenu(secondaryItems[0].id, "#boundary-secondary-list");
    assert
      .dom(moveItemSelector("up"))
      .doesNotExist(
        "the first row of the second member cannot step into the preceding member"
      );

    // A member's boundary is spoken by the accelerator, the one path that still
    // reaches it now the destination declines the press itself.
    await moveViaChord(secondaryItems[0].id, "up", "#boundary-secondary-list");

    assert.strictEqual(
      onMove.callCount,
      0,
      "a refused local boundary move commits nothing to the group"
    );
    assert.true(
      announce.calledOnceWith("Secondary Alpha is already first"),
      "and the reader is told they reached the member's boundary"
    );
  });

  test("DReorderableList accepts a cross-list drop on an empty member root", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const emptyItems = [];
    const movedItem = primaryItems[0];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="empty-source-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="empty"
            @listLabel="Empty links"
            @items={{emptyItems}}
            @key="id"
            @label={{label}}
            id="empty-target-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#empty-source-list");
    const target = "#empty-target-list";
    assert
      .dom(target)
      .hasClass(
        "d-reorderable-list",
        "the empty destination keeps the standard list root"
      )
      .hasAttribute(
        "data-drop-target",
        "",
        "an empty grouped member registers its root as a drop target"
      );
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "dropping on the empty root calls the group callback once"
    );
    assert.deepEqual(
      onMove.firstCall.args[0],
      {
        method: "drag",
        item: movedItem,
        fromList: "primary",
        toList: "empty",
        fromIndex: 0,
        toIndex: 0,
        fromItems: primaryItems,
        toItems: emptyItems,
        proposedFromItems: [],
        proposedToItems: [movedItem],
      },
      "the empty-root drop removes the source and inserts at destination index zero"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the empty-root drop announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to Empty links, position 1 of 1`,
      "the empty destination announcement measures its proposed one-item list"
    );
  });

  test("DReorderableList keeps non-empty member roots out of drop targeting", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="non-empty-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    for (const root of [
      "#non-empty-primary-list",
      "#non-empty-secondary-list",
    ]) {
      assert
        .dom(root)
        .doesNotHaveAttribute(
          "data-drop-target",
          `${root} does not register its non-empty root for drops`
        );
      assert
        .dom(`${root} > .d-reorderable-list__row`)
        .hasAttribute(
          "data-drop-target",
          "",
          `${root} continues to accept drops on its row`
        );
    }
  });

  test("DReorderableList uses the standard cross-list announcement without a destination label", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const movedItem = primaryItems[0];
    const targetItem = secondaryItems[0];
    const proposedToItems = [movedItem, targetItem];
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary links"
            @items={{primaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-primary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="unlabelled-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(movedItem.id, "#unlabelled-primary-list");
    const target = rowSelector(targetItem.id, "#unlabelled-secondary-list");
    assertDragReady(assert, source, target);
    await simulateDrag(source, target, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(target, "before"),
    });

    assert.strictEqual(
      onMove.callCount,
      1,
      "the unlabelled destination still commits one cross-list move"
    );
    assert.strictEqual(
      announce.callCount,
      1,
      "the unlabelled destination still announces exactly once"
    );
    assert.strictEqual(
      announce.firstCall.args[0],
      `Moved ${label(movedItem)} to position 1 of ${proposedToItems.length}`,
      "the fallback announcement omits a destination list name"
    );
  });

  test("DReorderableList isolates grouped and standalone drag surfaces", async function (assert) {
    const groupedItems = [
      { id: "grouped-alpha", name: "Grouped Alpha" },
      { id: "grouped-bravo", name: "Grouped Bravo" },
    ];
    const standaloneItems = [
      { id: "standalone-alpha", name: "Standalone Alpha" },
      { id: "standalone-bravo", name: "Standalone Bravo" },
    ];
    const groupOnMove = sinon.spy();
    const standaloneOnMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{groupOnMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="grouped"
            @items={{groupedItems}}
            @key="id"
            @label={{label}}
            id="isolated-grouped-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
        <DReorderableList
          @items={{standaloneItems}}
          @key="id"
          @label={{label}}
          @onMove={{standaloneOnMove}}
          id="isolated-standalone-list"
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
          </:row>
        </DReorderableList>
      </template>
    );

    const groupedSource = rowSelector(
      groupedItems[0].id,
      "#isolated-grouped-list"
    );
    const groupedTarget = rowSelector(
      groupedItems[1].id,
      "#isolated-grouped-list"
    );
    const standaloneSource = rowSelector(
      standaloneItems[0].id,
      "#isolated-standalone-list"
    );
    const standaloneTarget = rowSelector(
      standaloneItems[1].id,
      "#isolated-standalone-list"
    );

    await simulateDrag(groupedSource, standaloneTarget, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(standaloneTarget, "before"),
    });

    await simulateDrag(standaloneSource, groupedTarget, {
      dataTransfer: new DataTransfer(),
      targetCoordinates: dropCoordinates(groupedTarget, "before"),
    });

    assert.strictEqual(
      groupOnMove.callCount,
      0,
      "the group rejects the standalone drag"
    );
    assert.strictEqual(
      standaloneOnMove.callCount,
      0,
      "the standalone list rejects the grouped drag"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "rejected drags across the isolation boundary are silent"
    );
  });

  test("a list torn down with its menu open leaves nothing registered", async function (assert) {
    // The menu's content is rendered by the app-root host and its lifecycle is
    // the service's, so neither ends when the list does. Without the list
    // cascading destruction into the coordinator, the instance stays in the
    // service's registry for the life of the app, holding the trigger element
    // and, through the menu data, the list itself.
    const items = objectItems();
    const state = new (class {
      @tracked showList = true;
    })();
    const menu = this.owner.lookup("service:menu");

    await render(
      <template>
        <DMenus />
        {{#if state.showList}}
          <DReorderableList
            @items={{items}}
            @key="id"
            @label={{label}}
            @onMove={{noop}}
            id="teardown-menu-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        {{/if}}
      </template>
    );

    await openMoveMenu("alpha", "#teardown-menu-list");
    assert.dom(".d-reorderable-list__move-item").exists("the menu is open");
    assert.strictEqual(
      menu.registeredMenus.size,
      1,
      "and the service is holding it"
    );

    state.showList = false;
    await settled();

    assert
      .dom("#teardown-menu-list")
      .doesNotExist("the list is fully unrendered with its menu still open");
    assert
      .dom(".d-reorderable-list__move-item")
      .doesNotExist("no menu content outlives the list that opened it");
    assert.strictEqual(
      menu.registeredMenus.size,
      0,
      "and nothing is left registered with the service"
    );
  });

  test("DReorderableList refuses a drop after the source member is torn down", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    const state = new (class {
      @tracked showPrimary = true;
    })();
    const onMove = sinon.spy();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{onMove}} as |group|>
          {{#if state.showPrimary}}
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="teardown-primary-list"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          {{/if}}
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @items={{secondaryItems}}
            @key="id"
            @label={{label}}
            id="teardown-secondary-list"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    const source = rowSelector(primaryItems[0].id, "#teardown-primary-list");
    const sourceHandle = `${source} .d-reorderable-list__handle`;
    const target = rowSelector(
      secondaryItems[0].id,
      "#teardown-secondary-list"
    );
    const dataTransfer = new DataTransfer();
    assert.dom(source).hasAttribute("data-drag-source", "");
    assert.dom(target).hasAttribute("data-drop-target", "");
    await dragEvent(sourceHandle, "dragstart", {
      dataTransfer,
      ...centerOf(sourceHandle),
    });

    state.showPrimary = false;
    await settled();

    assert
      .dom("#teardown-primary-list")
      .doesNotExist("the source member is fully unrendered mid-drag");
    const targetCoordinates = dropCoordinates(target, "before");
    await dragEvent(target, "dragenter", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "dragover", {
      dataTransfer,
      ...targetCoordinates,
    });
    await dragEvent(target, "drop", {
      dataTransfer,
      ...targetCoordinates,
    });

    assert.strictEqual(
      onMove.callCount,
      0,
      "the group refuses a drop whose source membership is gone"
    );
    assert.strictEqual(
      announce.callCount,
      0,
      "the refused teardown drop makes no announcement"
    );
  });

  test("DReorderableList rejects duplicate group listId registrations", async function (assert) {
    const primaryItems = [{ id: "primary-alpha", name: "Primary Alpha" }];
    const secondaryItems = [{ id: "secondary-alpha", name: "Secondary Alpha" }];
    let raised;

    setupOnerror((error) => {
      raised = error;
    });

    try {
      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="duplicate"
              @items={{secondaryItems}}
              @key="id"
              @label={{label}}
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );
    } finally {
      resetOnerror();
    }

    assert.true(
      /Assertion Failed:.*(duplicate|list.?id|unique)/i.test(
        raised?.message ?? ""
      ),
      "duplicate listId registration triggers a development assertion"
    );
  });

  test("a member's list label is read live rather than captured at registration", async function (assert) {
    const primary = trackedArray(objectItems());
    const secondary = trackedArray([
      { id: "secondary-alpha", name: "Secondary Alpha" },
    ]);
    const state = new (class {
      @tracked secondaryLabel = "Secondary";
    })();

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{noop}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="primary"
            @listLabel="Primary"
            @items={{primary}}
            @key="id"
            @label={{label}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="secondary"
            @listLabel={{state.secondaryLabel}}
            @items={{secondary}}
            @key="id"
            @label={{label}}
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    state.secondaryLabel = "Renamed";
    await settled();

    await openMoveMenu("alpha");

    assert
      .dom(moveItemSelector("list"))
      .hasText(
        "Move to Renamed",
        "a destination is named by what the list is called now, not by what it was called when it registered"
      );
  });

  /**
   * Two members that read as one run, which is the arrangement `@spill` is
   * for. The applier is the same shape a real consumer writes: the component
   * proposes an order and the store is the consumer's to update.
   */
  function spillFixture() {
    const first = trackedArray([
      { id: "alpha", name: "Alpha" },
      { id: "bravo", name: "Bravo" },
    ]);
    const second = trackedArray([{ id: "charlie", name: "Charlie" }]);
    const moves = [];
    const applyMove = (move) => {
      moves.push(move);
      const listFor = (id) => (id === "first" ? first : second);
      const from = listFor(move.fromList);
      from.splice(0, from.length, ...move.proposedFromItems);
      if (move.toList !== move.fromList) {
        const to = listFor(move.toList);
        to.splice(0, to.length, ...move.proposedToItems);
      }
    };
    return { first, second, moves, applyMove };
  }

  test("a spilling list carries a row past its own end into the next member", async function (assert) {
    const { first, second, moves, applyMove } = spillFixture();

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="first"
            @listLabel="First"
            @spill={{true}}
            @items={{first}}
            @key="id"
            @label={{label}}
            class="spill-first"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="second"
            @listLabel="Second"
            @spill={{true}}
            @items={{second}}
            @key="id"
            @label={{label}}
            class="spill-second"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveViaChord("bravo", "down", ".spill-first");

    assert.deepEqual(
      renderedItemOrder(".spill-first"),
      ["alpha"],
      "the row left the list it had run out of room in"
    );
    assert.deepEqual(
      renderedItemOrder(".spill-second"),
      ["bravo", "charlie"],
      "and entered the next one at the top, still travelling downwards"
    );
    assert.strictEqual(
      moves.at(-1).method,
      "keyboard",
      "the consumer is told what the reader actually did, not that a menu was used"
    );
    assert
      .dom(handleSelector("bravo", ".spill-second"))
      .isFocused("focus follows the row across, so a second press is possible");
  });

  test("a spilling list carries a row backwards onto the previous member's tail", async function (assert) {
    const { first, second, applyMove } = spillFixture();

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="first"
            @listLabel="First"
            @spill={{true}}
            @items={{first}}
            @key="id"
            @label={{label}}
            class="spill-first"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="second"
            @listLabel="Second"
            @spill={{true}}
            @items={{second}}
            @key="id"
            @label={{label}}
            class="spill-second"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveViaChord("charlie", "up", ".spill-second");

    assert.deepEqual(
      renderedItemOrder(".spill-first"),
      ["alpha", "bravo", "charlie"],
      "entering from below lands last, so the row keeps travelling upwards"
    );
    assert.deepEqual(
      renderedItemOrder(".spill-second"),
      [],
      "and the member it left is empty"
    );
  });

  test("the outermost end still refuses even when the list spills", async function (assert) {
    const { first, second, moves, applyMove } = spillFixture();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="first"
            @listLabel="First"
            @spill={{true}}
            @items={{first}}
            @key="id"
            @label={{label}}
            class="spill-first"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="second"
            @listLabel="Second"
            @spill={{true}}
            @items={{second}}
            @key="id"
            @label={{label}}
            class="spill-second"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveViaChord("charlie", "down", ".spill-second");

    assert.strictEqual(moves.length, 0, "there is nowhere further to go");
    assert.strictEqual(
      announce.lastCall.args[0],
      "Charlie is already last",
      "and reaching the end of the whole run is still spoken"
    );
  });

  test("without spill a member's boundary refuses as it always did", async function (assert) {
    const { first, second, moves, applyMove } = spillFixture();
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="first"
            @listLabel="First"
            @items={{first}}
            @key="id"
            @label={{label}}
            class="spill-first"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="second"
            @listLabel="Second"
            @items={{second}}
            @key="id"
            @label={{label}}
            class="spill-second"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await moveViaChord("bravo", "down", ".spill-first");

    assert.strictEqual(moves.length, 0, "a member keeps to its own edges");
    assert.strictEqual(
      announce.lastCall.args[0],
      "Bravo is already last",
      "and says so"
    );
    assert.deepEqual(renderedItemOrder(".spill-second"), ["charlie"]);
  });

  test("a spillable row is offered the step in its menu", async function (assert) {
    const { first, second, applyMove } = spillFixture();

    await render(
      <template>
        <DMenus />
        <DReorderableListGroup @onMove={{applyMove}} as |group|>
          <DReorderableList
            @group={{group}}
            @listId="first"
            @listLabel="First"
            @spill={{true}}
            @items={{first}}
            @key="id"
            @label={{label}}
            class="spill-first"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
          <DReorderableList
            @group={{group}}
            @listId="second"
            @listLabel="Second"
            @spill={{true}}
            @items={{second}}
            @key="id"
            @label={{label}}
            class="spill-second"
          >
            <:row as |item|>
              <span data-test-item={{item.id}}>{{item.name}}</span>
            </:row>
          </DReorderableList>
        </DReorderableListGroup>
      </template>
    );

    await openMoveMenu("bravo", ".spill-first");

    assert
      .dom(moveItemSelector("down"))
      .exists(
        "the last row of a spilling member can still step down, so the menu says so"
      );
    assert
      .dom(moveItemSelector("bottom"))
      .doesNotExist("but the end of this list is somewhere it already is");
  });
});
module("Integration | ui-kit | DReorderableList | nested", function (hooks) {
  setupRenderingTest(hooks);

  const INNER = ".nested-inner";

  /**
   * An outer list whose first row hosts a list of its own, which is the shape
   * any tree of reorderable things takes: sections holding rows, groups holding
   * members. Only the first outer row nests one, so a selector naming an inner
   * key can never also name an outer one.
   */
  function nestedItems() {
    return trackedArray([
      {
        id: "outer-a",
        name: "Outer A",
        children: trackedArray([
          { id: "one", name: "One" },
          { id: "two", name: "Two" },
        ]),
      },
      { id: "outer-b", name: "Outer B", children: null },
    ]);
  }

  test("an accelerator on a nested handle moves the nested row, not the outer one", async function (assert) {
    const outer = nestedItems();
    const inner = outer[0].children;
    const outerMove = sinon.spy();
    // A real handler, not a spy: the component never mutates `@items`, so a
    // spy alone would leave the rendered order unchanged whether the move
    // reached the right list or no list at all.
    const innerMove = sinon.spy(({ proposedFromItems }) =>
      inner.splice(0, inner.length, ...proposedFromItems)
    );

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{outer}}
          @key="id"
          @label={{label}}
          @onMove={{outerMove}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
            {{#if item.children}}
              <DReorderableList
                @items={{inner}}
                @key="id"
                @label={{label}}
                @onMove={{innerMove}}
                class="nested-inner"
              >
                <:row as |child|>
                  <span data-test-item={{child.id}}>{{child.name}}</span>
                </:row>
              </DReorderableList>
            {{/if}}
          </:row>
        </DReorderableList>
      </template>
    );

    await moveViaChord("one", "down", INNER);

    assert.true(
      innerMove.calledOnce,
      "the list the handle belongs to is the list that moves"
    );
    assert.false(
      outerMove.called,
      "and the list it is nested in never sees a key it does not own"
    );
    assert.deepEqual(
      renderedItemOrder(INNER),
      ["two", "one"],
      "the nested row moved"
    );
  });

  test("an accelerator on an outer handle still moves the outer row", async function (assert) {
    const outer = nestedItems();
    const inner = outer[0].children;
    const outerMove = sinon.spy();

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{outer}}
          @key="id"
          @label={{label}}
          @onMove={{outerMove}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
            {{#if item.children}}
              <DReorderableList
                @items={{inner}}
                @key="id"
                @label={{label}}
                @onMove={{noop}}
                class="nested-inner"
              >
                <:row as |child|>
                  <span data-test-item={{child.id}}>{{child.name}}</span>
                </:row>
              </DReorderableList>
            {{/if}}
          </:row>
        </DReorderableList>
      </template>
    );

    await moveViaChord("outer-a", "down");

    assert.true(outerMove.calledOnce, "the outer list moves its own row");
  });

  test("the outer cursor steps over a nested list's handles", async function (assert) {
    const outer = nestedItems();
    const inner = outer[0].children;

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{outer}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
            {{#if item.children}}
              <DReorderableList
                @items={{inner}}
                @key="id"
                @label={{label}}
                @onMove={{noop}}
                class="nested-inner"
              >
                <:row as |child|>
                  <span data-test-item={{child.id}}>{{child.name}}</span>
                </:row>
              </DReorderableList>
            {{/if}}
          </:row>
        </DReorderableList>
      </template>
    );

    const handle = find(handleSelector("outer-a"));
    handle.focus();
    await triggerKeyEvent(handle, "keydown", "ArrowDown");

    assert
      .dom(handleSelector("outer-b"))
      .isFocused(
        "the cursor walks the rows of the list it belongs to, not every handle beneath it"
      );
  });

  test("the nested cursor stops at its own end rather than escaping outwards", async function (assert) {
    const outer = nestedItems();
    const inner = outer[0].children;

    await render(
      <template>
        <DMenus />
        <DReorderableList
          @items={{outer}}
          @key="id"
          @label={{label}}
          @onMove={{noop}}
        >
          <:row as |item|>
            <span data-test-item={{item.id}}>{{item.name}}</span>
            {{#if item.children}}
              <DReorderableList
                @items={{inner}}
                @key="id"
                @label={{label}}
                @onMove={{noop}}
                class="nested-inner"
              >
                <:row as |child|>
                  <span data-test-item={{child.id}}>{{child.name}}</span>
                </:row>
              </DReorderableList>
            {{/if}}
          </:row>
        </DReorderableList>
      </template>
    );

    const handle = find(handleSelector("two", INNER));
    handle.focus();
    await triggerKeyEvent(handle, "keydown", "ArrowDown");

    assert
      .dom(handleSelector("two", INNER))
      .isFocused(
        "the last row of a nested list has nowhere further to go inside it"
      );
  });
});

module(
  "Integration | ui-kit | DReorderableList | group | rev42618",
  function (hooks) {
    setupRenderingTest(hooks);

    /**
     * Records every move and applies it to the tracked lists it names, the
     * way a real consumer's handler does, so a move that should not have
     * happened shows up in the DOM as well as in the log.
     */
    function recordingApplier(listsById) {
      const moves = [];
      const applyMove = (move) => {
        moves.push(move);
        const from = listsById[move.fromList];
        from.splice(0, from.length, ...move.proposedFromItems);
        if (move.toList !== move.fromList) {
          const to = listsById[move.toList];
          to.splice(0, to.length, ...move.proposedToItems);
        }
      };
      return { moves, applyMove };
    }

    test("rev42618 a disabled member is not offered as a menu destination", async function (assert) {
      const primaryItems = objectItems();
      const archiveItems = [{ id: "archived-alpha", name: "Archived Alpha" }];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{noop}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="rev-disabled-menu-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="archive"
              @listLabel="Archive"
              @disabled={{true}}
              @items={{archiveItems}}
              @key="id"
              @label={{label}}
              id="rev-disabled-menu-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await openMoveMenu(primaryItems[0].id, "#rev-disabled-menu-source");

      assert
        .dom(moveItemSelector("list"))
        .doesNotExist(
          "a member that cannot accept anything is not offered as somewhere to send a row"
        );
    });

    test("rev42618 a disabled member refuses a spilled move", async function (assert) {
      const primaryItems = trackedArray(objectItems());
      const archiveItems = trackedArray([
        { id: "archived-alpha", name: "Archived Alpha" },
      ]);
      const { moves, applyMove } = recordingApplier({
        primary: primaryItems,
        archive: archiveItems,
      });
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const lastItem = primaryItems.at(-1);

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @listLabel="Primary"
              @spill={{true}}
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="rev-spill-refused-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="archive"
              @listLabel="Archive"
              @disabled={{true}}
              @items={{archiveItems}}
              @key="id"
              @label={{label}}
              id="rev-spill-refused-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const archiveOrderBefore = renderedItemOrder("#rev-spill-refused-target");

      await moveViaChord(lastItem.id, "down", "#rev-spill-refused-source");

      assert.strictEqual(
        moves.length,
        0,
        "a spill aimed at a disabled member commits nothing"
      );
      assert.deepEqual(
        renderedItemOrder("#rev-spill-refused-target"),
        archiveOrderBefore,
        "the disabled member's rendered order is untouched"
      );
      assert.true(
        announce.calledWith(sinon.match(label(lastItem))),
        "the refusal is spoken as the row's own boundary"
      );
    });

    test("rev42618 a cross-list move refocuses the row it landed on", async function (assert) {
      const sourceItems = trackedArray([
        { id: "source-alpha", name: "Source Alpha" },
        { id: "source-bravo", name: "Source Bravo" },
      ]);
      const frozenItem = { id: "target-pinned", name: "Target Pinned" };
      const targetItems = trackedArray([
        frozenItem,
        { id: "target-alpha", name: "Target Alpha" },
      ]);
      const movable = (item) => item !== frozenItem;
      const { applyMove } = recordingApplier({
        source: sourceItems,
        target: targetItems,
      });
      const movedItem = sourceItems.at(-1);
      const otherTargetId = targetItems[1].id;

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="source"
              @listLabel="Source"
              @spill={{true}}
              @items={{sourceItems}}
              @key="id"
              @label={{label}}
              id="rev-refocus-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="target"
              @listLabel="Target"
              @movable={{movable}}
              @items={{targetItems}}
              @key="id"
              @label={{label}}
              id="rev-refocus-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveViaChord(movedItem.id, "down", "#rev-refocus-source");

      assert.deepEqual(
        renderedItemOrder("#rev-refocus-target"),
        [frozenItem.id, movedItem.id, otherTargetId],
        "the frozen row keeps index zero, so the arrival fills the first movable slot"
      );
      assert
        .dom(handleSelector(movedItem.id, "#rev-refocus-target"))
        .isFocused(
          "focus lands on the handle of the row that moved, in the list it moved into"
        );
    });

    test("rev42618 a cross-list move reports the slot the item landed in", async function (assert) {
      const sourceValues = ["bravo"];
      const secondValues = ["alpha", "bravo", "charlie"];
      const movedValue = sourceValues[0];
      const expectedProposed = [...secondValues, movedValue];
      const expectedToIndex = expectedProposed.length - 1;
      const onMove = sinon.spy();
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="index-source"
              @items={{sourceValues}}
              @key={{INDEX_KEY}}
              @label={{label}}
              id="rev-slot-source"
            >
              <:row as |item|>
                <span data-test-item={{item}}>{{item}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="index-second"
              @listLabel="Second"
              @items={{secondValues}}
              @key={{INDEX_KEY}}
              @label={{label}}
              id="rev-slot-second"
            >
              <:row as |item|>
                <span data-test-item={{item}}>{{item}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia("0", "list", "#rev-slot-source");

      assert.strictEqual(
        onMove.callCount,
        1,
        "the menu destination commits one move"
      );
      assert.deepEqual(
        onMove.firstCall.args[0].proposedToItems,
        expectedProposed,
        "the arriving duplicate lands at the end of the destination's proposal"
      );
      assert.strictEqual(
        onMove.firstCall.args[0].toIndex,
        expectedToIndex,
        "toIndex names the slot the item landed in, not the first equal value"
      );
      assert.true(
        announce.calledWith(
          sinon.match(
            `position ${expectedToIndex + 1} of ${expectedProposed.length}`
          )
        ),
        "the announcement places the row in the slot it landed in"
      );
    });

    test("rev42618 the move menu commits a cross-list move", async function (assert) {
      const firstItems = trackedArray([
        { id: "first-alpha", name: "First Alpha" },
        { id: "first-bravo", name: "First Bravo" },
      ]);
      const secondItems = trackedArray([
        { id: "second-alpha", name: "Second Alpha" },
      ]);
      const { moves, applyMove } = recordingApplier({
        first: firstItems,
        second: secondItems,
      });
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      const movedItem = firstItems[0];
      const expectedFirstOrder = firstItems
        .filter((item) => item !== movedItem)
        .map((item) => item.id);
      const expectedSecondOrder = [
        ...secondItems.map((item) => item.id),
        movedItem.id,
      ];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="first"
              @listLabel="First links"
              @items={{firstItems}}
              @key="id"
              @label={{label}}
              id="rev-menu-commit-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="second"
              @listLabel="Second links"
              @items={{secondItems}}
              @key="id"
              @label={{label}}
              id="rev-menu-commit-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia(movedItem.id, "list", "#rev-menu-commit-source");

      assert.deepEqual(
        renderedItemOrder("#rev-menu-commit-source"),
        expectedFirstOrder,
        "the row left the list it was sent from"
      );
      assert.deepEqual(
        renderedItemOrder("#rev-menu-commit-target"),
        expectedSecondOrder,
        "and joined the destination at its end"
      );
      assert.strictEqual(
        moves.length,
        1,
        "choosing the destination commits exactly one move"
      );
      assert.strictEqual(
        moves[0].method,
        "menu",
        "a menu choice is reported as one"
      );
      assert.strictEqual(
        moves[0].fromList,
        "first",
        "the move names the member the row left"
      );
      assert.strictEqual(
        moves[0].toList,
        "second",
        "and the member it entered"
      );
      assert.strictEqual(
        announce.callCount,
        1,
        "the cross-list menu move announces exactly once"
      );
      assert.true(
        announce.firstCall.args[0].includes("Second links"),
        "and the announcement names the destination list"
      );
    });

    test("rev42618 the move menu spills at a boundary", async function (assert) {
      const firstItems = trackedArray([
        { id: "run-alpha", name: "Run Alpha" },
        { id: "run-bravo", name: "Run Bravo" },
      ]);
      const secondItems = trackedArray([
        { id: "run-charlie", name: "Run Charlie" },
      ]);
      const { moves, applyMove } = recordingApplier({
        first: firstItems,
        second: secondItems,
      });
      const movedItem = firstItems.at(-1);
      const expectedFirstOrder = firstItems
        .filter((item) => item !== movedItem)
        .map((item) => item.id);
      const expectedSecondOrder = [
        movedItem.id,
        ...secondItems.map((item) => item.id),
      ];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="first"
              @listLabel="First"
              @spill={{true}}
              @items={{firstItems}}
              @key="id"
              @label={{label}}
              id="rev-menu-spill-first"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="second"
              @listLabel="Second"
              @items={{secondItems}}
              @key="id"
              @label={{label}}
              id="rev-menu-spill-second"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      await moveVia(movedItem.id, "down", "#rev-menu-spill-first");

      assert.deepEqual(
        renderedItemOrder("#rev-menu-spill-first"),
        expectedFirstOrder,
        "the last row stepped out of the list it had run out of room in"
      );
      assert.deepEqual(
        renderedItemOrder("#rev-menu-spill-second"),
        expectedSecondOrder,
        "and entered the next member at the top"
      );
      assert.strictEqual(
        moves.length,
        1,
        "the boundary step commits exactly one move"
      );
      assert.strictEqual(
        moves[0].method,
        "menu",
        "a spill chosen from the menu is reported as a menu move, not a keyboard one"
      );
    });

    test("rev42618 a frozen destination row keeps its slot when an item arrives", async function (assert) {
      const sourceItems = [
        { id: "drag-source-alpha", name: "Drag Source Alpha" },
      ];
      const frozenItem = { id: "drag-pinned", name: "Drag Pinned" };
      const targetItems = [
        { id: "drag-target-alpha", name: "Drag Target Alpha" },
        frozenItem,
        { id: "drag-target-charlie", name: "Drag Target Charlie" },
      ];
      const frozenIndex = targetItems.indexOf(frozenItem);
      const movable = (item) => item !== frozenItem;
      const onMove = sinon.spy();

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="source"
              @items={{sourceItems}}
              @key="id"
              @label={{label}}
              id="rev-frozen-drop-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            <DReorderableList
              @group={{group}}
              @listId="target"
              @movable={{movable}}
              @items={{targetItems}}
              @key="id"
              @label={{label}}
              id="rev-frozen-drop-target"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
          </DReorderableListGroup>
        </template>
      );

      const source = rowSelector(sourceItems[0].id, "#rev-frozen-drop-source");
      const target = rowSelector(
        targetItems.at(-1).id,
        "#rev-frozen-drop-target"
      );
      assertDragReady(assert, source, target);
      await simulateDrag(source, target, {
        dataTransfer: new DataTransfer(),
        targetCoordinates: dropCoordinates(target, "before"),
      });

      assert.strictEqual(onMove.callCount, 1, "the drop commits one move");
      assert.strictEqual(
        onMove.firstCall.args[0].proposedToItems[frozenIndex],
        frozenItem,
        "the frozen destination row holds its slot while the arrival is interleaved around it"
      );
    });

    test("rev42618 a stale cross-list destination announces its refusal", async function (assert) {
      const primaryItems = objectItems();
      const secondaryItems = [
        { id: "stale-secondary-alpha", name: "Stale Secondary Alpha" },
      ];
      const state = new (class {
        @tracked showSecondary = true;
      })();
      const onMove = sinon.spy();
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{onMove}} as |group|>
            <DReorderableList
              @group={{group}}
              @listId="primary"
              @items={{primaryItems}}
              @key="id"
              @label={{label}}
              id="rev-stale-source"
            >
              <:row as |item|>
                <span data-test-item={{item.id}}>{{item.name}}</span>
              </:row>
            </DReorderableList>
            {{#if state.showSecondary}}
              <DReorderableList
                @group={{group}}
                @listId="secondary"
                @listLabel="Secondary links"
                @items={{secondaryItems}}
                @key="id"
                @label={{label}}
                id="rev-stale-target"
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
            {{/if}}
          </DReorderableListGroup>
        </template>
      );

      await openMoveMenu(primaryItems[0].id, "#rev-stale-source");
      assert
        .dom(moveItemSelector("list"))
        .exists(
          "the destination stands in the menu while its member is mounted"
        );

      state.showSecondary = false;
      await settled();

      await click(moveItemSelector("list"));

      assert.strictEqual(
        onMove.callCount,
        0,
        "no move is recorded against a member that no longer exists"
      );
      assert.true(
        announce
          .getCalls()
          .some((call) => String(call.args[0]).includes("Could not move")),
        "the refusal itself is spoken, not a success sentence for a move that never happened"
      );
    });

    test("rev42618 spill follows document order not registration order", async function (assert) {
      const alphaItems = trackedArray([
        { id: "alpha-one", name: "Alpha One" },
        { id: "alpha-two", name: "Alpha Two" },
      ]);
      const betaItems = trackedArray([{ id: "beta-one", name: "Beta One" }]);
      const members = trackedArray([
        {
          listId: "alpha",
          listLabel: "Alpha",
          className: "doc-order-alpha",
          items: alphaItems,
        },
        {
          listId: "beta",
          listLabel: "Beta",
          className: "doc-order-beta",
          items: betaItems,
        },
      ]);
      const { applyMove } = recordingApplier({
        alpha: alphaItems,
        beta: betaItems,
      });
      const alphaOrderBefore = alphaItems.map((item) => item.id);
      const movedItem = betaItems[0];

      await render(
        <template>
          <DMenus />
          <DReorderableListGroup @onMove={{applyMove}} as |group|>
            {{#each members key="listId" as |member|}}
              <DReorderableList
                @group={{group}}
                @listId={{member.listId}}
                @listLabel={{member.listLabel}}
                @spill={{true}}
                @items={{member.items}}
                @key="id"
                @label={{label}}
                class={{member.className}}
              >
                <:row as |item|>
                  <span data-test-item={{item.id}}>{{item.name}}</span>
                </:row>
              </DReorderableList>
            {{/each}}
          </DReorderableListGroup>
        </template>
      );

      // Reversing the keyed array moves the members' DOM nodes without
      // destroying the components, so the group's registration order still
      // says "alpha" came first. Only a neighbour lookup sorted by document
      // position can tell that "beta" now renders above it; a
      // registration-ordered one would refuse this move as the group's end.
      const [alphaMember, betaMember] = [...members];
      members.splice(0, members.length, betaMember, alphaMember);
      await settled();

      await moveViaChord(movedItem.id, "down", ".doc-order-beta");

      assert.deepEqual(
        renderedItemOrder(".doc-order-alpha"),
        [movedItem.id, ...alphaOrderBefore],
        "the row spilled into the member that now renders below its own"
      );
      assert.deepEqual(
        renderedItemOrder(".doc-order-beta"),
        [],
        "and left the member it ran out of"
      );
    });
  }
);
