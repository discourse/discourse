import DModal from "discourse/ui-kit/d-modal";
import GraphvizDiagram from "./graphviz-diagram";

const GraphvizFullscreen = <template>
  <DModal @closeModal={{@closeModal}} class="graphviz-fullscreen">
    <GraphvizDiagram
      @src={{@model.src}}
      @engine={{@model.engine}}
      @enableZoom={{true}}
    />
  </DModal>
</template>;

export default GraphvizFullscreen;
