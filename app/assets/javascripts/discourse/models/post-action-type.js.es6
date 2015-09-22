import RestModel from 'discourse/models/rest';

const PostActionType = RestModel.extend({
  notCustomFlag: Em.computed.not('is_custom_flag')
});

export const MAX_MESSAGE_LENGTH = 500;

export default PostActionType;
