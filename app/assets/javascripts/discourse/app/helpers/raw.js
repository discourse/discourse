import { helperContext, registerUnbound } from "discourse-common/lib/helpers";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { htmlSafe } from "@ember/template";
import { RUNTIME_OPTIONS } from "discourse-common/lib/raw-handlebars-helpers";
import { buildResolver } from "discourse-common/resolver";

let resolver;
let viewsByTemplateName = new Map();

function lookupView(templateName) {
  if (!viewsByTemplateName.has(templateName)) {
    if (!resolver) {
      resolver = buildResolver("discourse").create();
    }

    viewsByTemplateName.set(templateName, resolver.customResolve({
      type: "raw-view",
      fullNameWithoutType: templateName,
    }));
  }

  return viewsByTemplateName.get(templateName);
}

function renderRaw(ctx, template, templateName, params) {
  params = Object.assign({}, params);
  params.parent = params.parent || ctx;

  let context = helperContext();
  if (!params.view) {
    const viewClass = lookupView(templateName);

    if (viewClass) {
      params.view = viewClass.create(params, context);
    }

    if (!params.view) {
      params = Object.assign({}, params, context);
    }
  }

  return htmlSafe(template(params, RUNTIME_OPTIONS));
}

registerUnbound("raw", function (templateName, params) {
  templateName = templateName.replace(".", "/");

  const template = findRawTemplate(templateName);
  if (!template) {
    // eslint-disable-next-line no-console
    console.warn("Could not find raw template: " + templateName);
    return;
  }
  return renderRaw(this, template, templateName, params);
});
