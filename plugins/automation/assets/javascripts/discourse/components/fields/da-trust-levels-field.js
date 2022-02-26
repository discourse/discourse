import BaseField from "./da-base-field";
import { reads } from "@ember/object/computed";

export default BaseField.extend({
  allTrustLevel: reads("site.trustLevels"),
});
