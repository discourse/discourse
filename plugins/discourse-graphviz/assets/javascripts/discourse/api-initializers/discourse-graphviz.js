import { apiInitializer } from "discourse/lib/api";
import GraphvizInline from "../components/graphviz-inline.gjs";
import richEditorExtension from "../lib/rich-editor-extension.js";

function applyGraphviz(element, helper) {
  const src = element.textContent.trim();
  if (!src) {
    return;
  }

  const wrapper = document.createElement("div");
  wrapper.classList.add("graphviz-wrapper");
  helper.renderGlimmer(wrapper, GraphvizInline, {
    src,
    engine: element.dataset.engine,
  });
  element.replaceWith(wrapper);
}

export default apiInitializer((api) => {
  api.registerRichEditorExtension(richEditorExtension);

  api.decorateCookedElement((element, helper) => {
    element
      .querySelectorAll("div.graphviz")
      .forEach((graph) => applyGraphviz(graph, helper));
  });

  api.addComposerToolbarPopupMenuOption({
    icon: "diagram-project",
    label: "graphviz.composer_title",
    action: (toolbarEvent) => {
      toolbarEvent.applySurround(
        "\n[graphviz]\n",
        "\n[/graphviz]\n",
        "graphviz_sample",
        { multiline: false }
      );
    },
  });
});
