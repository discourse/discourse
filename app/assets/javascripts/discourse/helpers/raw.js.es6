import { registerUnbound } from "discourse-common/lib/helpers";
import { findRawTemplate } from "discourse/lib/raw-templates";

let _injections;

function renderRaw(ctx, container, template, templateName, params) {
  params = jQuery.extend({}, params);
  params.parent = params.parent || ctx;

  if (!_injections) {
    _injections = {
      siteSettings: container.lookup("site-settings:main"),
      currentUser: container.lookup("current-user:main"),
      site: container.lookup("site:main"),
      session: container.lookup("session:main"),
      topicTrackingState: container.lookup("topic-tracking-state:main")
    };
  }

  if (!params.view) {
    const module = `discourse/raw-views/${templateName}`;
    if (requirejs.entries[module]) {
      const viewClass = requirejs(module, null, null, true);
      if (viewClass && viewClass.default) {
        params.view = viewClass.default.create(params, _injections);
      }
    }

    if (!params.view) {
      params = jQuery.extend({}, params, _injections);
    }
  }

  return new Handlebars.SafeString(template(params));
}

registerUnbound("raw", function(templateName, params) {
  templateName = templateName.replace(".", "/");

  const container = Discourse.__container__;
  const template = findRawTemplate(templateName);
  if (!template) {
    // eslint-disable-next-line no-console
    console.warn("Could not find raw template: " + templateName);
    return;
  }
  return renderRaw(this, container, template, templateName, params);
});
