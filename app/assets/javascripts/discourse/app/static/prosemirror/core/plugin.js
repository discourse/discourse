import { Plugin } from "prosemirror-state";

export function extractNodeViews(extensions, pluginParams) {
  /** @type {Record<string, import('prosemirror-view').NodeViewConstructor>} */
  const allNodeViews = {};
  for (const { nodeViews } of extensions) {
    if (nodeViews) {
      for (let [name, NodeViewClass] of Object.entries(nodeViews)) {
        if (!NodeViewClass.toString().startsWith("class")) {
          NodeViewClass = NodeViewClass(pluginParams);
        }
        allNodeViews[name] = (...args) => new NodeViewClass(...args);
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
