const dynamicJsTemplate = document.querySelector("#dynamic-test-js");

const params = new URLSearchParams(document.location.search);
const skipPlugins = params.get("qunit_skip_plugins");

(async function setup() {
  for (const element of dynamicJsTemplate.content.childNodes) {
    if (skipPlugins && element.dataset?.discoursePlugin) {
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
