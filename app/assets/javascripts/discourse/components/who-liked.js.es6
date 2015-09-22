import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  rerenderTriggers: ['users.length'],

  renderString(buffer) {
    const users = this.get('users');
    if (users && users.length > 0) {
      buffer.push("<div class='who-liked'>");
      let iconsHtml = "";
      users.forEach(function(u) {
        iconsHtml += "<a href=\"" + Discourse.getURL("/users/") + u.get('username_lower') + "\" data-user-card=\"" + u.get('username_lower') + "\">";
        iconsHtml += Discourse.Utilities.avatarImg({
          size: 'small',
          avatarTemplate: u.get('avatar_template'),
          title: u.get('username')
        });
        iconsHtml += "</a>";
      });
      buffer.push(I18n.t('post.actions.people.like',{icons: iconsHtml}));
      buffer.push("</div>");
    } else {
      buffer.push("<span></span>");
    }
  }
});
