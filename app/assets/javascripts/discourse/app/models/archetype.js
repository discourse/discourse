import { gt, not } from "@ember/object/computed";
import RestModel from "discourse/models/rest";
import { propertyEqual } from "discourse/lib/computed";

export default RestModel.extend({
  hasOptions: gt("options.length", 0),
  isDefault: propertyEqual("id", "site.default_archetype"),
  notDefault: not("isDefault"),
});
