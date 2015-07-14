import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  likedUsers: Ember.computed.alias('post.likeAction.users'),
  rerenderTriggers: ['likedUsers.length'],

  renderString(buffer) {
    const likedUsers = this.get('likedUsers');
    if (likedUsers && likedUsers.length > 0) {
      buffer.push("<div class='who-liked'>");
      let iconsHtml = "";
      likedUsers.forEach(function(u) {
        iconsHtml += "<a href=\"" + Discourse.getURL("/users/") + u.get('username_lower') + "\" data-user-card=\"" + u.get('username_lower') + "\">";
        iconsHtml += Discourse.Utilities.avatarImg({
          size: 'small',
          avatarTemplate: u.get('avatarTemplate'),
          title: u.get('username')
        });
        iconsHtml += "</a>";
      });
      buffer.push(I18n.t('post.actions.people.like',{icons: iconsHtml}));
      buffer.push("</div>");
    }
  }
});
