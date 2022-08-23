const dynamicJsTemplate = document.querySelector("#dynamic-test-js");

const params = new URLSearchParams(document.location.search);
const skipPlugins = params.get("qunit_skip_plugins");

for(const element of Array.from(dynamicJsTemplate.content.childNodes)){
  const clone = element.cloneNode(true);

  if(skipPlugins && clone.dataset?.discoursePlugin){
    continue;
  }

  if(clone.tagName === "SCRIPT" && clone.innerHTML.includes("EmberENV.TESTS_FILE_LOADED")){
    // Inline script introduced by ember-cli. Incompatible with CSP and our custom plugin JS loading system
    // https://github.com/ember-cli/ember-cli/blob/04a38fda2c/lib/utilities/ember-app-utils.js#L131
    // We re-implement in test-boot-ember-cli.js
    continue;
  }

  if(clone.tagName=== "SCRIPT"){
    clone.async = false;
  }

  document.body.appendChild(clone)
}
