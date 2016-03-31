import { autoUpdatingRelativeAge } from 'discourse/lib/formatter';

export function actionDescriptionHtml(actionCode, createdAt, username) {
  const dt = new Date(createdAt);
  const when = autoUpdatingRelativeAge(dt, { format: 'medium-with-ago' });
  const who = username ? `<a class="mention" href="/users/${username}">@${username}</a>` : "";
  return I18n.t(`action_codes.${actionCode}`, { who, when }).htmlSafe();
}

export function actionDescription(actionCode, createdAt, username) {
  return function() {
    const ac = this.get(actionCode);
    if (ac) {
      return actionDescriptionHtml(ac, this.get(createdAt), this.get(username));
    }
  }.property(actionCode, createdAt);
}

export default Ember.Component.extend({
  layoutName: 'components/small-action', // needed because `time-gap` inherits from this
  classNames: ['small-action'],

  description: actionDescription('actionCode', 'post.created_at', 'post.action_code_who'),

  actions: {
    edit() {
      this.sendAction('editPost', this.get('post'));
    },

    delete() {
      this.sendAction('deletePost', this.get('post'));
    }
  }

});
