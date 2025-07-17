const dynamicJsTemplate = document.querySelector("#dynamic-test-js");

const params = new URLSearchParams(document.location.search);
const target = params.get("target") || "core";

const loadPlugins = new Set();

if (target === "all" || target === "plugins") {
  // Load all plugins
  dynamicJsTemplate.content
    .querySelectorAll("script[data-discourse-plugin]")
    .forEach((el) => loadPlugins.add(el.dataset.discoursePlugin));
} else if (target !== "core") {
  // Load a specific plugin
  loadPlugins.add(target);
  dynamicJsTemplate.content
    .querySelector(`script[data-discourse-plugin="${target}"]`)
    ?.dataset.discourseTestRequiredPlugins?.split(",")
    .forEach((plugin) => {
      loadPlugins.add(plugin);
    });
}
(async function setup() {
  for (const element of dynamicJsTemplate.content.childNodes) {
    const pluginName = element.dataset?.discoursePlugin;
    if (pluginName && !loadPlugins.has(pluginName)) {
      continue;
    }

    if (
      element.tagName === "SCRIPT" &&
      element.innerHTML.includes("EmberENV.TESTS_FILE_LOADED")
    ) {
      // Inline script introduced by ember-cli. Incompatible with CSP and our custom plugin JS loading system
      // https://github.com/ember-cli/ember-cli/blob/04a38fda2c/lib/utilities/ember-app-utils.js#L131
      // We re-implement in test-boot-ember-cli.js
      continue;
    }

    const clone = element.cloneNode(true);

    if (clone.tagName === "SCRIPT") {
      clone.async = false;
    }

    document.querySelector("discourse-dynamic-test-js").appendChild(clone);

    if (clone.tagName === "LINK" && clone["rel"] === "stylesheet") {
      await new Promise((resolve) => (clone.onload = resolve));
    }
  }
})();
