import { propertyEqual } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  hasOptions: Em.computed.gt("options.length", 0),
  isDefault: propertyEqual("id", "site.default_archetype"),
  notDefault: Em.computed.not("isDefault")
});
