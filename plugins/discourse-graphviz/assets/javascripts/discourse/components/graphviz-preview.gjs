import GraphvizDiagram from "./graphviz-diagram.gjs";

export default <template>
  <GraphvizDiagram @engine={{@node.attrs.engine}} @src={{@source}} />
</template>
