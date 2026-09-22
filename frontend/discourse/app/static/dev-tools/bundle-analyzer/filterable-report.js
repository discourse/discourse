import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

// Shared scaffolding for the two report panes. What the browser fetched and
// what the reader excluded both live on the graph, so a pane only owns the
// filter box.
export default class FilterableReport extends Component {
  @tracked filter = "";

  get analysis() {
    return this.args.analysis;
  }

  get loaded() {
    return this.analysis.loaded;
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }
}
