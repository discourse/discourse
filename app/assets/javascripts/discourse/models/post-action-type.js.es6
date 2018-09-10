import RestModel from "discourse/models/rest";

export const MAX_MESSAGE_LENGTH = 500;

export default RestModel.extend({
  notCustomFlag: Em.computed.not("is_custom_flag")
});
