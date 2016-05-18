import { createWidget } from 'discourse/widgets/widget';
import { avatarAtts } from 'discourse/widgets/actions-summary';
import { h } from 'virtual-dom';

const LIKE_ACTION = 2;

function animateHeart($elem, start, end, complete) {
  if (Ember.testing) { return Ember.run(this, complete); }

  $elem.stop()
       .css('textIndent', start)
       .animate({ textIndent: end }, {
          complete,
          step(now) {
            $(this).css('transform','scale('+now+')');
          },
          duration: 150
        }, 'linear');
}

const _builders = {};
const _extraButtons = {};

export function addButton(name, builder) {
  _extraButtons[name] = builder;
}

function registerButton(name, builder) {
  _builders[name] = builder;
}

registerButton('like', attrs => {
  if (!attrs.showLike) { return; }
  const className = attrs.liked ? 'toggle-like has-like fade-out' : 'toggle-like like';

  const button = {
    action: 'like',
    icon: 'heart',
    className
  };

  if (attrs.canToggleLike) {
    button.title = attrs.liked ? 'post.controls.undo_like' : 'post.controls.like';
  } else if (attrs.liked) {
    button.title = 'post.controls.has_liked';
    button.disabled = true;
  }
  return button;
});

registerButton('like-count', attrs => {
  const count = attrs.likeCount;

  if (count > 0) {
    const title = attrs.liked
      ? count === 1 ? 'post.has_likes_title_only_you' : 'post.has_likes_title_you'
      : 'post.has_likes_title';

    return { action: 'toggleWhoLiked',
      title,
      className: 'like-count highlight-action',
      contents: I18n.t("post.has_likes", { count }),
      titleOptions: {count: attrs.liked ? (count-1) : count }
    };
  }
});

registerButton('flag', attrs => {
  if (attrs.canFlag) {
    return { action: 'showFlags',
             title: 'post.controls.flag',
             icon: 'flag',
             className: 'create-flag' };
  }
});

registerButton('edit', attrs => {
  if (attrs.canEdit) {
    return {
      action: 'editPost',
      className: 'edit',
      title: 'post.controls.edit',
      icon: 'pencil',
      alwaysShowYours: true
    };
  }
});

registerButton('replies', (attrs, state, siteSettings) => {
  const replyCount = attrs.replyCount;

  if (!replyCount) { return; }

  // Omit replies if the setting `suppress_reply_directly_below` is enabled
  if (replyCount === 1 &&
      attrs.replyDirectlyBelow &&
      siteSettings.suppress_reply_directly_below) {
    return;
  }

  return {
    action: 'toggleRepliesBelow',
    className: 'show-replies',
    icon: state.repliesShown ? 'chevron-up' : 'chevron-down',
    titleOptions: { count: replyCount },
    title: 'post.has_replies',
    labelOptions: { count: replyCount },
    label: 'post.has_replies',
    iconRight: true
  };
});


registerButton('share', attrs => {
  return {
    action: 'share',
    title: 'post.controls.share',
    icon: 'link',
    data: {
      'share-url': attrs.shareUrl,
      'post-number': attrs.post_number
    }
  };
});

registerButton('reply', attrs => {
  const args = {
    action: 'replyToPost',
    title: 'post.controls.reply',
    icon: 'reply',
    className: 'reply create fade-out'
  };

  if (!attrs.canCreatePost) { return; }

  if (!attrs.mobileView) {
    args.label = 'topic.reply.title';
  }

  return args;
});

registerButton('bookmark', attrs => {
  if (!attrs.canBookmark) { return; }

  let iconClass = 'read-icon';
  let buttonClass = 'bookmark';
  let tooltip = 'bookmarks.not_bookmarked';

  if (attrs.bookmarked) {
    iconClass += ' bookmarked';
    buttonClass += ' bookmarked';
    tooltip = 'bookmarks.created';
  }

  return { action: 'toggleBookmark',
           title: tooltip,
           className: buttonClass,
           contents: h('div', { className: iconClass }) };
});

registerButton('admin', attrs => {
  if (!attrs.canManage && !attrs.canWiki) { return; }
  return { action: 'openAdminMenu',
           title: 'post.controls.admin',
           className: 'show-post-admin-menu',
           icon: 'wrench' };
});

registerButton('delete', attrs => {
  if (attrs.canRecoverTopic) {
    return { action: 'recoverPost', title: 'topic.actions.recover', icon: 'undo', className: 'recover' };
  } else if (attrs.canDeleteTopic) {
    return { action: 'deletePost', title: 'topic.actions.delete', icon: 'trash-o', className: 'delete' };
  } else if (attrs.canRecover) {
    return { action: 'recoverPost', title: 'post.controls.undelete', icon: 'undo', className: 'recover' };
  } else if (attrs.canDelete) {
    return { action: 'deletePost', title: 'post.controls.delete', icon: 'trash-o', className: 'delete' };
  }
});

export default createWidget('post-menu', {
  tagName: 'section.post-menu-area.clearfix',

  defaultState() {
    return { collapsed: true, likedUsers: [], adminVisible: false };
  },

  buildKey: attrs => `post-menu-${attrs.id}`,

  attachButton(name, attrs) {
    const builder = _builders[name];
    if (builder) {
      const buttonAtts = builder(attrs, this.state, this.siteSettings);
      if (buttonAtts) {
        return this.attach('button', buttonAtts);
      }
    }
  },

  html(attrs, state) {
    const { siteSettings } = this;

    const hiddenSetting = (siteSettings.post_menu_hidden_items || '');
    const hiddenButtons = hiddenSetting.split('|').filter(s => {
      return !attrs.bookmarked || s !== 'bookmark';
    });

    const allButtons = [];
    let visibleButtons = [];
    siteSettings.post_menu.split('|').forEach(i => {
      const button = this.attachButton(i, attrs);
      if (button) {
        allButtons.push(button);
        if ((attrs.yours && button.attrs.alwaysShowYours) || (hiddenButtons.indexOf(i) === -1)) {
          visibleButtons.push(button);
        }
      }
    });

    // Only show ellipsis if there is more than one button hidden
    // if there are no more buttons, we are not collapsed
    if (!state.collapsed || (allButtons.length <= visibleButtons.length + 1)) {
      visibleButtons = allButtons;
      if (state.collapsed) { state.collapsed = false; }
    } else {
      const showMore = this.attach('button', {
        action: 'showMoreActions',
        title: 'show_more',
        className: 'show-more-actions',
        icon: 'ellipsis-h' });
      visibleButtons.splice(visibleButtons.length - 1, 0, showMore);
    }

    Object.keys(_extraButtons).forEach(k => {
      const builder = _extraButtons[k];
      if (builder) {
        const buttonAtts = builder(attrs, this.state, this.siteSettings);
        if (buttonAtts) {
          const { position, beforeButton } = buttonAtts;
          delete buttonAtts.position;

          let button = this.attach('button', buttonAtts);

          if (beforeButton) {
            button = h('span', [beforeButton(h), button]);
          }

          if (button) {
            switch(position) {
              case 'first':
                visibleButtons.unshift(button);
                break;
              case 'second':
                visibleButtons.splice(1, 0, button);
                break;
              case 'second-last-hidden':
                if (!state.collapsed) {
                  visibleButtons.splice(visibleButtons.length-2, 0, button);
                }
                break;
              default:
                visibleButtons.push(button);
                break;
            }
          }
        }
      }
    });

    const postControls = [];

    const repliesButton = this.attachButton('replies', attrs);
    if (repliesButton) {
      postControls.push(repliesButton);
    }

    postControls.push(h('div.actions', visibleButtons));
    if (state.adminVisible) {
      postControls.push(this.attach('post-admin-menu', attrs));
    }

    const contents = [ h('nav.post-controls.clearfix', postControls) ];
    if (state.likedUsers.length) {
      contents.push(this.attach('small-user-list', {
        users: state.likedUsers,
        addSelf: attrs.liked,
        listClassName: 'who-liked',
        description: 'post.actions.people.like'
      }));
    }

    return contents;
  },

  openAdminMenu() {
    this.state.adminVisible = true;
  },

  closeAdminMenu() {
    this.state.adminVisible = false;
  },

  showMoreActions() {
    this.state.collapsed = false;
  },

  like() {
    const attrs = this.attrs;
    if (attrs.liked) {
      return this.sendWidgetAction('toggleLike');
    }

    const $heart = $(`[data-post-id=${attrs.id}] .fa-heart`);
    $heart.closest('button').addClass('has-like');

    const scale = [1.0, 1.5];
    return new Ember.RSVP.Promise(resolve => {
      animateHeart($heart, scale[0], scale[1], () => {
        animateHeart($heart, scale[1], scale[0], () => {
          this.sendWidgetAction('toggleLike').then(() => resolve());
        });
      });
    });
  },

  refreshLikes() {
    if (this.state.likedUsers.length) {
      return this.getWhoLiked();
    }
  },

  getWhoLiked() {
    const { attrs, state } = this;

    return this.store.find('post-action-user', { id: attrs.id, post_action_type_id: LIKE_ACTION }).then(users => {
      state.likedUsers = users.map(avatarAtts);
    });
  },

  toggleWhoLiked() {
    const state = this.state;
    if (state.likedUsers.length) {
      state.likedUsers = [];
    } else {
      return this.getWhoLiked();
    }
  },
});
