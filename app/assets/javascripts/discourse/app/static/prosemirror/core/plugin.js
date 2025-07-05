import { Plugin } from "prosemirror-state";

/*
  There are 3 ways to define a node view:

  Setting a node view class directly (e.g. code-block)
  `nodeViews: { nodeName: NodeViewClass }`

  Setting a node view class as returned by a function, when plugin params are needed (e.g. footnote)
  `nodeViews: { nodeName: (pluginParams) => NodeViewClass }`

  Setting a node view instance as returned by a function, when plugin params are needed (e.g. image)
  `nodeViews: { nodeName: (pluginParams) => (...args) => nodeViewInstance }`
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
