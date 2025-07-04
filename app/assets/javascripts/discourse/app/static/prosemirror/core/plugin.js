import { Plugin } from "prosemirror-state";

/*
  nodeViews: { nodeName: NodeViewClass }
  nodeViews: { nodeName: (pluginParams) => NodeViewClass }
  nodeViews: { nodeName: (pluginParams) => (...args) => new NodeViewClass(...args) }
*/
export function extractNodeViews(extensions, pluginParams) {
  /** @type {Record<string, import('prosemirror-view').NodeViewConstructor>} */
  const allNodeViews = {};
  for (const { nodeViews } of extensions) {
    if (nodeViews) {
      for (let [name, nodeView] of Object.entries(nodeViews)) {
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
