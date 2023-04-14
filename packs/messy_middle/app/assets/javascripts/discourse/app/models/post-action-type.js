import RestModel from "discourse/models/rest";
import { not } from "@ember/object/computed";

export const MAX_MESSAGE_LENGTH = 500;

export default RestModel.extend({
  notCustomFlag: not("is_custom_flag"),
});
