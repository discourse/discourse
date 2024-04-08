/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/

import Automation from "../admin/models/discourse-automation-automation";
import Field from "../admin/models/discourse-automation-field";

let sequence = 0;

function fieldFabricator(args = {}) {
  const template = args.template || {};
  template.accepts_placeholders = args.accepts_placeholders ?? true;
  template.accepted_contexts = args.accepted_contexts ?? [];
  template.name = args.name ?? "name";
  template.component = args.component ?? "boolean";
  template.value = args.value ?? false;
  template.is_required = args.is_required ?? false;
  template.extra = args.extra ?? {};
  return Field.create(template, {
    type: args.target ?? "script",
    name: "script_name",
  });
}

function automationFabricator(args = {}) {
  const automation = new Automation();
  automation.id = args.id || sequence++;
  automation.trigger = {
    id: (sequence++).toString(),
  };
  automation.script = {
    id: (sequence++).toString(),
  };

  return automation;
}

export default {
  field: fieldFabricator,
  automation: automationFabricator,
};
