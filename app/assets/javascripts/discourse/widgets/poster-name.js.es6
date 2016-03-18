import { iconNode } from 'discourse/helpers/fa-icon';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

function sanitizeName(name){
  return name.toLowerCase().replace(/[\s_-]/g,'');
}

export default createWidget('poster-name', {
  tagName: 'div.names.trigger-user-card',

  // TODO: Allow extensibility
  posterGlyph(attrs) {
    if (attrs.moderator) {
      return iconNode('shield', { title: I18n.t('user.moderator_tooltip') });
    }
  },

  userLink(attrs, text) {
    return h('a', { attributes: {
      href: attrs.usernameUrl,
      'data-auto-route': true,
      'data-user-card': attrs.username
    } }, text);
  },

  html(attrs) {
    const username = attrs.username;
    const classNames = ['username'];

    if (attrs.staff) { classNames.push('staff'); }
    if (attrs.admin) { classNames.push('admin'); }
    if (attrs.moderator) { classNames.push('moderator'); }
    if (attrs.new_user) { classNames.push('new-user'); }

    const primaryGroupName = attrs.primary_group_name;
    if (primaryGroupName && primaryGroupName.length) {
      classNames.push(primaryGroupName);
    }
    const nameContents = [ this.userLink(attrs, attrs.username) ];
    const glyph = this.posterGlyph(attrs);
    if (glyph) { nameContents.push(glyph); }

    const contents = [h('span', { className: classNames.join(' ') }, nameContents)];
    const name = attrs.name;
    if (name && this.siteSettings.display_name_on_posts && sanitizeName(name) !== sanitizeName(username)) {
      contents.push(h('span.full-name', this.userLink(attrs, name)));
    }
    const title = attrs.user_title;
    if (title && title.length) {
      let titleContents = title;
      if (primaryGroupName) {
        const href = Discourse.getURL(`/groups/${primaryGroupName}`);
        titleContents = h('a.user-group', { attributes: { href } }, title);
      }
      contents.push(h('span.user-title', titleContents));
    }

    return contents;
  }
});
