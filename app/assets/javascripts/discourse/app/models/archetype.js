import { gt, not } from "@ember/object/computed";
import { propertyEqual } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";

export default class Archetype extends RestModel {
  @gt("options.length", 0) hasOptions;
  @propertyEqual("id", "site.default_archetype") isDefault;
  @not("isDefault") notDefault;
}
