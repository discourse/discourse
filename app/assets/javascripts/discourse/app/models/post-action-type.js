import { equal, not } from "@ember/object/computed";
import RestModel from "discourse/models/rest";

export const MAX_MESSAGE_LENGTH = 500;

export default class PostActionType extends RestModel {
  @not("is_custom_flag") notCustomFlag;
  @equal("name_key", "illegal") isIllegal;
}
