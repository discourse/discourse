import FeatureModules from "./-virtual-features";

export default function loadPluginFeatures() {
  const features = [];

  for (let { name, module } of FeatureModules) {
    loadFeature(features, name, module);
  }

  for (let name of Object.keys(requirejs.entries)) {
    if (name.startsWith("discourse/plugins/")) {
      // all of the modules under discourse-markdown or markdown-it
      // directories are considered additional markdown "features" which
      // may define their own rules
      if (
        name.includes("/discourse-markdown/") ||
        name.includes("/markdown-it/")
      ) {
        loadFeature(features, name, requirejs(name));
      }
    }
  }

  return features;
}

function loadFeature(features, moduleName, module) {
  if (module && module.setup) {
    const id = moduleName.split("/").reverse()[0];
    const { setup, priority = 0 } = module;
    features.unshift({ id, setup, priority });
  }
}
