import { registerUnbound } from "discourse-common/lib/helpers";
import EmberObject from "@ember/object";

registerUnbound("field-for-template", function (template, target, fields) {
  let field = fields.find(
    (f) =>
      f.name === template.name &&
      f.component === template.component &&
      f.target === target
  );

  if (!field) {
    field = EmberObject.create({
      component: template.component,
      name: template.name,
      target,
      metadata: { value: template?.value },
    });
    fields.push(field);
  }

  return field;
});
