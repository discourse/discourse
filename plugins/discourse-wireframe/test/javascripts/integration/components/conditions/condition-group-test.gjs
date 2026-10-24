import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ConditionGroup from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-group";

class State {
  @tracked node = [{ type: "route", pages: ["CATEGORY_PAGES"] }];
}

module(
  "Discourse Wireframe | Integration | conditions | condition-group",
  function (hooks) {
    setupRenderingTest(hooks);

    test("an open rule stays open when its tree is rebuilt by an edit", async function (assert) {
      const state = new State();
      const conditionTypes = this.owner
        .lookup("service:blocks")
        .listConditionTypes();
      const noop = () => {};
      const rootPath = [];

      await render(
        <template>
          <ConditionGroup
            @conditionTypes={{conditionTypes}}
            @isRoot={{true}}
            @node={{state.node}}
            @onInsertGroup={{noop}}
            @onInsertLeaf={{noop}}
            @onRemoveNode={{noop}}
            @onSetCombinator={{noop}}
            @onUpdateLeaf={{noop}}
            @path={{rootPath}}
          />
        </template>
      );

      await click(".wireframe-condition-rule__header");
      assert.dom(".wireframe-condition-rule").hasClass("--expanded");

      // An edit replaces the tree with fresh objects.
      state.node = [
        { type: "route", pages: ["CATEGORY_PAGES"], params: { categoryId: 7 } },
      ];
      await settled();

      assert
        .dom(".wireframe-condition-rule")
        .hasClass("--expanded", "the rule keeps its open state");
    });
  }
);
