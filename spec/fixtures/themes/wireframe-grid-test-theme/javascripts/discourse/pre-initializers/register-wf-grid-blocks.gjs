import Component from "@glimmer/component";
import { block } from "discourse/blocks";

// Trivial leaf blocks used as grid cells in the wireframe editor system test.
// Each renders a stable, queryable marker so the spec can assert which cell
// holds which block before / after a drag.

@block("wf-grid-cell-a")
export class WfGridCellA extends Component {
  <template>
    <div class="wf-grid-cell-a">Cell A</div>
  </template>
}

@block("wf-grid-cell-b")
export class WfGridCellB extends Component {
  <template>
    <div class="wf-grid-cell-b">Cell B</div>
  </template>
}
