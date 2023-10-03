/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/

import Field from "../admin/models/discourse-automation-field";
import Automation from "../admin/models/discourse-automation-automation";

let sequence = 0;

function fieldFabricator(args = {}) {
  const template = args.template || {};
  template.accepts_placeholders = args.accepts_placeholders ?? true;
  template.name = args.name ?? "name";
  template.component = args.component ?? "boolean";
  template.value = args.value ?? false;
  template.is_required = args.is_required ?? false;
  template.extra = args.extra ?? {};
  return Field.create(template, args.target ?? "script");
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
