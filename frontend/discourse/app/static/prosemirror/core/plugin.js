import { Plugin } from "prosemirror-state";
import GlimmerNodeView from "../lib/glimmer-node-view";

/*
  There are 3 ways to define a node view:

  Setting a node view class directly (e.g. code-block)
  `nodeViews: { nodeName: NodeViewClass }`

  Setting a node view class as returned by a function, when plugin params are needed (e.g. footnote)
  `nodeViews: { nodeName: (pluginParams) => NodeViewClass }`

  Setting a Glimmer component with auto-wrapping (recommended for Glimmer components)
  `nodeViews: { nodeName: { component: GlimmerComponent } }`

  The Glimmer component descriptor supports additional options:
  - `name: "customName"` - CSS class suffix (defaults to the key)
  - `hasContent: true` - for nodes with editable content inside
  - `shouldRender: ({ node, view, getPos, pluginParams }) => boolean` - for conditional rendering
*/
export function extractNodeViews(extensions, pluginParams) {
  /** @type {Record<string, import('prosemirror-view').NodeViewConstructor>} */
  const allNodeViews = {};
  for (const { nodeViews } of extensions) {
    if (nodeViews) {
      for (let [name, nodeView] of Object.entries(nodeViews)) {
        // Check if nodeView is a Glimmer component descriptor
        if (nodeView && typeof nodeView === "object" && nodeView.component) {
          allNodeViews[name] = (node, view, getPos) => {
            if (
              nodeView.shouldRender &&
              !nodeView.shouldRender({ node, view, getPos, pluginParams })
            ) {
              return null;
            }

            return new GlimmerNodeView({
              node,
              view,
              getPos,
              pluginParams,
              component: nodeView.component,
              name: nodeView.name || name,
              hasContent: nodeView.hasContent,
            });
          };
          continue;
        }

        // node view can be a function, to which we pass pluginParams
        if (!nodeView.toString().startsWith("class")) {
          nodeView = nodeView(pluginParams);
        }

        // directly or returned by the function, we may have a class
        if (nodeView.toString().startsWith("class")) {
          allNodeViews[name] = (...args) => new nodeView(...args);
        } else {
          allNodeViews[name] = nodeView;
        }
      }
    }
  }
  return allNodeViews;
}

export function extractPlugins(extensions, params, view) {
  return (
    extensions
      .flatMap((extension) => extension.plugins || [])
      .flatMap((plugin) => processPlugin(plugin, params, view))
      // filter async plugins from initial load
      .filter(Boolean)
  );
}

function processPlugin(pluginArg, params, handleAsyncPlugin) {
  if (typeof pluginArg === "function") {
    const ret = pluginArg(params);

    if (ret instanceof Promise) {
      ret.then((plugin) => handleAsyncPlugin(processPlugin(plugin, params)));
      return;
    }

    return processPlugin(ret, params, handleAsyncPlugin);
  }

  if (pluginArg instanceof Array) {
    return pluginArg.map((plugin) =>
      processPlugin(plugin, params, handleAsyncPlugin)
    );
  }

  if (pluginArg instanceof Plugin) {
    return pluginArg;
  }

  return new Plugin(pluginArg);
}
