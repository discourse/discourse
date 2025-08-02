/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/

import ApplicationInstance from "@ember/application/instance";
import { setOwner } from "@ember/owner";
import { incrementSequence } from "discourse/lib/fabricators";
import Automation from "../models/discourse-automation-automation";
import Field from "../models/discourse-automation-field";

export default class AutomationFabricators {
  constructor(owner) {
    if (owner && !(owner instanceof ApplicationInstance)) {
      throw new Error(
        "First argument of AutomationFabricators constructor must be the owning ApplicationInstance"
      );
    }
    setOwner(this, owner);
  }

  field(args = {}) {
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

  automation(args = {}) {
    const automation = new Automation();
    automation.id = args.id || incrementSequence();
    automation.trigger = {
      id: incrementSequence().toString(),
    };
    automation.script = {
      id: incrementSequence().toString(),
    };

    return automation;
  }
}
