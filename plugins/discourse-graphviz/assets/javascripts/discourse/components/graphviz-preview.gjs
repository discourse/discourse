import GraphvizDiagram from "./graphviz-diagram";

export default <template>
  <GraphvizDiagram @engine={{@node.attrs.engine}} @src={{@source}} />
</template>
