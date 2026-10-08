import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { withPluginApi } from "discourse/lib/plugin-api";

// Trivial leaf blocks used as grid cells in the wireframe editor system test.
// Each renders a stable, queryable marker class so the spec can assert which
// cell holds which block before / after a drag.

@block("theme:wireframe-grid-test:wf-grid-cell-a")
export class WfGridCellA extends Component {
  <template>
    <div class="wf-grid-cell-a">Cell A</div>
  </template>
}

@block("theme:wireframe-grid-test:wf-grid-cell-b")
export class WfGridCellB extends Component {
  <template>
    <div class="wf-grid-cell-b">Cell B</div>
  </template>
}

// Pre-initializer that registers the test blocks. Runs before
// "freeze-block-registry" so the blocks are in the registry before it locks.
export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(WfGridCellA);
      api.registerBlock(WfGridCellB);
    });
  },
};
