const dynamicJsTemplate = document.querySelector("#dynamic-test-js");

const params = new URLSearchParams(document.location.search);
const target = params.get("target") || "core";

// Same list maintained in qunit_controller.rb
const alwaysRequiredPlugins = ["discourse-local-dates"];

const requiredPluginInfo = JSON.parse(
  dynamicJsTemplate.content.querySelector("#discourse-required-plugin-info")
    ?.innerHTML || "{}"
);

(async function setup() {
  for (const element of dynamicJsTemplate.content.childNodes) {
    const pluginName = element.dataset?.discoursePlugin;

    if (pluginName && target === "core") {
      continue;
    }

    const shouldLoad =
      !pluginName ||
      ["all", "plugins"].includes(target) ||
      pluginName === "_all" ||
      target === pluginName ||
      alwaysRequiredPlugins.includes(pluginName) ||
      requiredPluginInfo[target]?.includes(pluginName);

    if (!shouldLoad) {
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
