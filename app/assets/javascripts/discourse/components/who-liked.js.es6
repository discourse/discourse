import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  classNames: ['who-liked'],
  likedUsers: Ember.computed.alias('post.actionByName.like.users'),
  rerenderTriggers: ['likedUsers.length'],

  renderString(buffer) {
    const likedUsers = this.get('likedUsers');
    if (likedUsers && likedUsers.length > 0) {
      buffer.push("<i class='fa fa-heart'></i>");
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
      buffer.push(iconsHtml);
    }
  }
});
