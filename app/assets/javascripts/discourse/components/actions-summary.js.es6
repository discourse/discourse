import StringBuffer from 'discourse/mixins/string-buffer';
import { iconHTML } from 'discourse/helpers/fa-icon';
import { autoUpdatingRelativeAge } from 'discourse/lib/formatter';
import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'section',
  classNameBindings: [':post-actions', 'hidden'],
  actionsSummary: Em.computed.alias('post.actionsWithoutLikes'),
  emptySummary: Em.computed.empty('actionsSummary'),
  hidden: Em.computed.and('emptySummary', 'post.notDeleted'),
  usersByType: null,

  rerenderTriggers: ['actionsSummary.@each', 'post.deleted'],

  @on('init')
  initUsersByType() {
    this.set('usersByType', {});
  },

  // This was creating way too many bound ifs and subviews in the handlebars version.
  renderString(buffer) {
    const usersByType = this.get('usersByType');

    if (!this.get('emptySummary')) {
      this.get('actionsSummary').forEach(function(c) {
        const id = c.get('id');
        const users = usersByType[id] || [];

        buffer.push("<div class='post-action'>");

        const renderLink = (dataAttribute, text) => {
          buffer.push(` <span class='action-link ${dataAttribute}-action'><a href data-${dataAttribute}='${id}'>${text}</a>.</span>`);
        };

        // TODO multi line expansion for flags
        let iconsHtml = "";
        if (users.length) {
          let postUrl;
          users.forEach(function(u) {
            const username = u.get('username_lower');

            iconsHtml += `<a href="${Discourse.getURL("/users")}${username}" data-user-card="${username}">`;
            if (u.post_url) {
              postUrl = postUrl || u.post_url;
            }
            iconsHtml += Discourse.Utilities.avatarImg({
              size: 'small',
              avatarTemplate: u.get('avatar_template'),
              title: u.get('username')
            });
            iconsHtml += "</a>";
          });

          let key = 'post.actions.people.' + c.get('actionType.name_key');
          if (postUrl) { key = key + "_with_url"; }

          // TODO postUrl might be uninitialized? pick a good default
          buffer.push(" " + I18n.t(key, { icons: iconsHtml, postUrl: postUrl}) + ".");
        }

        if (users.length === 0) {
          renderLink('who-acted', c.get('description'));
        }

        if (c.get('can_undo')) {
          renderLink('undo', I18n.t("post.actions.undo." + c.get('actionType.name_key')));
        }
        if (c.get('can_defer_flags')) {
          renderLink('defer-flags', I18n.t("post.actions.defer_flags", { count: c.count }));
        }


        buffer.push("</div>");
      });
    }

    const post = this.get('post');
    if (post.get('deleted')) {
      buffer.push("<div class='post-action'>" +
                  iconHTML('fa-trash-o') + '&nbsp;' +
                  Discourse.Utilities.tinyAvatar(post.get('postDeletedBy.avatar_template'), {title: post.get('postDeletedBy.username')}) +
                  autoUpdatingRelativeAge(new Date(post.get('postDeletedAt'))) +
                  "</div>");
    }
  },

  actionTypeById(actionTypeId) {
    return this.get('actionsSummary').findProperty('id', actionTypeId);
  },

  click(e) {
    const $target = $(e.target);
    let actionTypeId;

    const post = this.get('post');

    if (actionTypeId = $target.data('defer-flags')) {
      this.actionTypeById(actionTypeId).deferFlags(post);
      return false;
    }

    // User wants to know who actioned it
    const usersByType = this.get('usersByType');
    if (actionTypeId = $target.data('who-acted')) {
      this.actionTypeById(actionTypeId).loadUsers(post).then(users => {
        usersByType[actionTypeId] = users;
        this.rerender();
      });
      return false;
    }

    if (actionTypeId = $target.data('undo')) {
      this.get('actionsSummary').findProperty('id', actionTypeId).undo(post);
      return false;
    }

    return false;
  }
});
