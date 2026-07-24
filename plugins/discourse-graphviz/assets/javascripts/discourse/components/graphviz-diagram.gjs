import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { generateGraph } from "../lib/render-graphviz";

export default class GraphvizDiagram extends Component {
  @tracked zoomed = false;

  @action
  loadGraph() {
    return generateGraph(this.args.src, this.args.engine);
  }

  @action
  toggleZoom(event) {
    event.preventDefault();
    if (!this.args.enableZoom) {
      return;
    }
    this.zoomed = !this.zoomed;
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div
      class={{dConcatClass
        "graphviz-diagram"
        (if @enableZoom "zoomable")
        (if this.zoomed "zoomed")
      }}
      {{on "click" this.toggleZoom}}
    >
      <DAsyncContent @asyncData={{this.loadGraph}}>
        <:content as |svg|>
          {{svg}}
        </:content>
        <:error as |error|>
          <div class="graph-error">{{error.message}}</div>
        </:error>
      </DAsyncContent>
    </div>
  </template>
}
