import BaseField from "./da-base-field";
import { reads } from "@ember/object/computed";

export default class TrustLevelsField extends BaseField {
  @reads("site.trustLevels") allTrustLevel;
}
