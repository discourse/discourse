const dynamicJsTemplate = document.querySelector("#dynamic-test-js");
const outputNode = document.querySelector("discourse-dynamic-test-js");

const params = new URLSearchParams(document.location.search);
const target = params.get("target") || "core";

(async function setup() {
  const rootUrl = document.querySelector("link[rel='canonical']").href;
  const response = await fetch(
    `${rootUrl}bootstrap/plugin-test-info.json?target=${target}`
  );
  const data = await response.json();

  dynamicJsTemplate.content.firstElementChild.insertAdjacentHTML(
    "beforebegin",
    data.html
  );

  window._discourseQunitPluginNames = data.all_plugins;

  window.CLIENT_SITE_SETTINGS_WITH_DEFAULTS = JSON.parse(
    data.site_settings_json
  );

  for (const element of dynamicJsTemplate.content.childNodes) {
    if (
      element.tagName === "SCRIPT" &&
      element.innerHTML.includes("EmberENV.TESTS_FILE_LOADED")
    ) {
      // Inline script introduced by ember-cli. Incompatible with CSP and our custom plugin JS loading system
      // https://github.com/ember-cli/ember-cli/blob/04a38fda2c/lib/utilities/ember-app-utils.js#L131
      // We re-implement in test-boot-ember-cli.js
      continue;
    }

    if (element.type === "importmap") {
      // For some reason, adding the cloned version of the importmap doesn't work properly.
      // Re-creating from scratch does the trick.
      const importmap = document.createElement("script");
      importmap.type = "importmap";
      importmap.textContent = element.textContent;
      outputNode.append(importmap);
      continue;
    }

    const clone = element.cloneNode(true);

    if (clone.tagName === "SCRIPT") {
      clone.async = false;
    }

    outputNode.appendChild(clone);

    if (clone.tagName === "LINK" && clone["rel"] === "stylesheet") {
      await new Promise((resolve) => (clone.onload = resolve));
    }
  }
})();
