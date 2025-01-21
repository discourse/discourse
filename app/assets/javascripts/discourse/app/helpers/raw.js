import Helper from "@ember/component/helper";
import { registerDestructor } from "@ember/destroyable";
import { getOwner, setOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { bind } from "discourse/lib/decorators";
import { helperContext, registerRawHelper } from "discourse/lib/helpers";
import { RUNTIME_OPTIONS } from "discourse/lib/raw-handlebars-helpers";
import { findRawTemplate } from "discourse/lib/raw-templates";

function renderRaw(ctx, template, templateName, params) {
  params = { ...params };
  params.parent ||= ctx;

  let context = helperContext();
  if (!params.view) {
    const viewClass = context.registry.resolve(`raw-view:${templateName}`);

    if (viewClass) {
      setOwner(params, getOwner(context));
      params.view = viewClass.create(params, context);
    }

    if (!params.view) {
      params = { ...params, ...context };
    }
  }

  return htmlSafe(template(params, RUNTIME_OPTIONS));
}

const helperFunction = function (templateName, params) {
  templateName = templateName.replace(".", "/");

  const template = findRawTemplate(templateName);
  if (!template) {
    // eslint-disable-next-line no-console
    console.warn("Could not find raw template: " + templateName);
    return;
  }
  return renderRaw(this, template, templateName, params);
};

registerRawHelper("raw", helperFunction);

export default class RawHelper extends Helper {
  @service renderGlimmer;

  compute(args, params) {
    registerDestructor(this, this.cleanup);
    return helperFunction(...args, params);
  }

  @bind
  cleanup() {
    schedule("afterRender", () => this.renderGlimmer.cleanup());
  }
}
