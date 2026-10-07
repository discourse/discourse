import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import GraphvizDiagram from "./graphviz-diagram";
import GraphvizFullscreen from "./graphviz-fullscreen";

export default class GraphvizInline extends Component {
  @service modal;

  @action
  fullscreen() {
    this.modal.show(GraphvizFullscreen, {
      model: {
        src: this.args.data.src,
        engine: this.args.data.engine,
      },
    });
  }

  <template>
    <div class="graphviz-diagram-controls">
      <DButton
        class="btn-flat graphviz-fullscreen-button"
        @action={{this.fullscreen}}
        @icon="discourse-expand"
      />
    </div>

    <GraphvizDiagram @engine={{@data.engine}} @src={{@data.src}} />
  </template>
}
