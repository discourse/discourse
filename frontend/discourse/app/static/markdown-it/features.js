export default function loadPluginFeatures() {
  const features = [];

  for (let moduleName of Object.keys(requirejs.entries)) {
    if (moduleName.startsWith("discourse/plugins/")) {
      // all of the modules under discourse-markdown or markdown-it
      // directories are considered additional markdown "features" which
      // may define their own rules
      if (
        moduleName.includes("/discourse-markdown/") ||
        moduleName.includes("/markdown-it/")
      ) {
        const module = requirejs(moduleName);

        if (module && module.setup) {
          const id = moduleName.split("/").reverse()[0];
          const { setup, priority = 0 } = module;
          features.unshift({ id, setup, priority });
        }
      }
    }
  }

  return features;
}
