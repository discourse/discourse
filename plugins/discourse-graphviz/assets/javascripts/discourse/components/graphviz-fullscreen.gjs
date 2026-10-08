import DModal from "discourse/ui-kit/d-modal";
import GraphvizDiagram from "./graphviz-diagram";

const GraphvizFullscreen = <template>
  <DModal class="graphviz-fullscreen" @closeModal={{@closeModal}}>
    <GraphvizDiagram
      @enableZoom={{true}}
      @engine={{@model.engine}}
      @src={{@model.src}}
    />
  </DModal>
</template>;

export default GraphvizFullscreen;
