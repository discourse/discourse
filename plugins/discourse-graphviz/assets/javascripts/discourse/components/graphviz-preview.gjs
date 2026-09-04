import GraphvizDiagram from "./graphviz-diagram";

export default <template>
  <GraphvizDiagram @src={{@source}} @engine={{@node.attrs.engine}} />
</template>
