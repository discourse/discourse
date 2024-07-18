import { equal } from "@ember/object/computed";
import RestModel from "discourse/models/rest";

export const MAX_MESSAGE_LENGTH = 500;

export default class PostActionType extends RestModel {
  @equal("name_key", "illegal") isIllegal;
}
