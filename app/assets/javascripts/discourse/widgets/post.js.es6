import PostCooked from 'discourse/widgets/post-cooked';
import { createWidget, applyDecorators } from 'discourse/widgets/widget';
import { iconNode } from 'discourse/helpers/fa-icon';
import { transformBasicPost } from 'discourse/lib/transform-post';
import { h } from 'virtual-dom';
import DiscourseURL from 'discourse/lib/url';
import { dateNode } from 'discourse/helpers/node';

export function avatarImg(wanted, attrs) {
  const size = Discourse.Utilities.translateSize(wanted);
  const url = Discourse.Utilities.avatarUrl(attrs.template, size);

  // We won't render an invalid url
  if (!url || url.length === 0) { return; }
  const title = attrs.username;

  const properties = {
    attributes: { alt: '', width: size, height: size, src: Discourse.getURLWithCDN(url), title },
    className: 'avatar'
  };

  return h('img', properties);
}

export function avatarFor(wanted, attrs) {
  return h('a', {
    className: `trigger-user-card ${attrs.className || ''}`,
    attributes: { href: attrs.url, 'data-user-card': attrs.username }
  }, avatarImg(wanted, attrs));
}

createWidget('select-post', {
  tagName: 'div.select-posts',

  html(attrs) {
    const buttons = [];

    if (attrs.replyCount > 0 && !attrs.selected) {
      buttons.push(this.attach('button', { label: 'topic.multi_select.select_replies', action: 'selectReplies' }));
    }

    const selectPostKey = attrs.selected ? 'topic.multi_select.selected' : 'topic.multi_select.select';
    buttons.push(this.attach('button', { className: 'select-post',
                                         label: selectPostKey,
                                         labelOptions: { count: attrs.selectedPostsCount },
                                         action: 'selectPost' }));
    return buttons;
  }
});

createWidget('reply-to-tab', {
  tagName: 'a.reply-to-tab',

  defaultState() {
    return { loading: false };
  },

  html(attrs, state) {
    if (state.loading) { return I18n.t('loading'); }

    return [iconNode('mail-forward'),
            ' ',
            avatarImg.call(this,'small',{
              template: attrs.replyToAvatarTemplate,
              username: attrs.replyToUsername
            }),
            ' ',
            h('span', attrs.replyToUsername)];
  },

  click() {
    this.state.loading = true;
    this.sendWidgetAction('toggleReplyAbove').then(() => this.state.loading = false);
  }
});

createWidget('post-avatar', {
  tagName: 'div.topic-avatar',

  html(attrs) {
    let body;
    if (!attrs.user_id) {
      body = h('i', { className: 'fa fa-trash-o deleted-user-avatar' });
    } else {
      body = avatarFor.call(this, 'large', {
        template: attrs.avatar_template,
        username: attrs.username,
        url: attrs.usernameUrl,
        className: 'main-avatar'
      });
    }

    return [body, h('div.poster-avatar-extra')];
  }
});


createWidget('wiki-edit-button', {
  tagName: 'div.post-info.wiki',
  title: 'post.wiki.about',

  html() {
    return iconNode('pencil-square-o');
  },

  click() {
    this.sendWidgetAction('editPost');
  }
});

createWidget('post-email-indicator', {
  tagName: 'div.post-info.via-email',
  title: 'post.via_email',

  buildClasses(attrs) {
    return attrs.canViewRawEmail ? 'raw-email' : null;
  },

  html() {
    return iconNode('envelope-o');
  },

  click() {
    if (this.attrs.canViewRawEmail) {
      this.sendWidgetAction('showRawEmail');
    }
  }
});

function showReplyTab(attrs, siteSettings) {
  return attrs.replyToUsername &&
         (!attrs.replyDirectlyAbove || !siteSettings.suppress_reply_directly_above);
}

createWidget('post-meta-data', {
  tagName: 'div.topic-meta-data',
  html(attrs) {
    const result = [this.attach('poster-name', attrs)];

    if (attrs.isWhisper) {
      result.push(h('div.post-info.whisper', {
        attributes: { title: I18n.t('post.whisper') },
      }, iconNode('eye-slash')));
    }

    const createdAt = new Date(attrs.created_at);
    if (createdAt) {
      result.push(h('div.post-info',
        h('a.post-date', {
          attributes: {
            href: attrs.shareUrl,
            'data-share-url': attrs.shareUrl,
            'data-post-number': attrs.post_number
          }
        }, dateNode(createdAt))
      ));
    }

    if (attrs.via_email) {
      result.push(this.attach('post-email-indicator', attrs));
    }

    if (attrs.version > 1) {
      result.push(this.attach('post-edits-indicator', attrs));
    }

    if (attrs.wiki) {
      result.push(this.attach('wiki-edit-button', attrs));
    }

    if (attrs.multiSelect) {
      result.push(this.attach('select-post', attrs));
    }

    if (showReplyTab(attrs, this.siteSettings)) {
      result.push(this.attach('reply-to-tab', attrs));
    }

    result.push(h('div.read-state', {
      className: attrs.read ? 'read' : null,
      attributes: {
        title: I18n.t('post.unread')
      }
    }, iconNode('circle')));

    return result;
  }
});

createWidget('expand-hidden', {
  tagName: 'a.expand-hidden',

  html() {
    return I18n.t('post.show_hidden');
  },

  click() {
    this.sendWidgetAction('expandHidden');
  }
});

createWidget('expand-post-button', {
  tagName: 'button.btn.expand-post',
  buildKey: attrs => `expand-post-button-${attrs.id}`,

  defaultState() {
    return { loadingExpanded: false };
  },

  html(attrs, state) {
    if (state.loadingExpanded) {
      return I18n.t('loading');
    } else {
      return [I18n.t('post.show_full'), "..."];
    }
  },

  click() {
    this.state.loadingExpanded = true;
    this.sendWidgetAction('expandFirstPost');
  }
});

class DecoratorHelper {
  constructor(widget) {
    this.container = widget.container;
    this._widget = widget;
  }

  getModel() {
    return this._widget.findAncestorModel();
  }
}

createWidget('post-contents', {
  buildKey: attrs => `post-contents-${attrs.id}`,

  defaultState() {
    return { expandedFirstPost: false, repliesBelow: [] };
  },

  buildClasses(attrs) {
    const classes = ['regular'];
    if (!this.state.repliesShown) {
      classes.push('contents');
    }
    if (showReplyTab(attrs, this.siteSettings)) {
      classes.push('avoid-tab');
    }
    return classes;
  },

  html(attrs, state) {
    let result = [new PostCooked(attrs, new DecoratorHelper(this))];
    result = result.concat(applyDecorators(this, 'after-cooked', attrs, state));

    if (attrs.cooked_hidden) {
      result.push(this.attach('expand-hidden', attrs));
    }

    if (!state.expandedFirstPost && attrs.expandablePost) {
      result.push(this.attach('expand-post-button', attrs));
    }

    const extraState = { state: { repliesShown: !!state.repliesBelow.length } };
    result.push(this.attach('post-menu', attrs, extraState));

    const repliesBelow = state.repliesBelow;
    if (repliesBelow.length) {
      result.push(h('section.embedded-posts.bottom', repliesBelow.map(p => this.attach('embedded-post', p))));
    }

    return result;
  },

  toggleRepliesBelow() {
    if (this.state.repliesBelow.length) {
      this.state.repliesBelow = [];
      return;
    }

    const post = this.findAncestorModel();
    const topicUrl = post ? post.get('topic.url') : null;
    return this.store.find('post-reply', { postId: this.attrs.id }).then(posts => {
      this.state.repliesBelow = posts.map(p => {
        p.shareUrl = `${topicUrl}/${p.post_number}`;
        return transformBasicPost(p);
      });
    });
  },

  expandFirstPost() {
    const post = this.findAncestorModel();
    return post.expand().then(() => this.state.expandedFirstPost = true);
  }
});

createWidget('post-body', {
  tagName: 'div.topic-body',

  html(attrs) {
    const postContents = this.attach('post-contents', attrs);
    const result = [this.attach('post-meta-data', attrs), postContents];

    result.push(this.attach('actions-summary', attrs));
    if (attrs.showTopicMap) {
      result.push(this.attach('topic-map', attrs));
    }

    return result;
  }
});

createWidget('post-article', {
  tagName: 'article.boxed.onscreen-post',
  buildKey: attrs => `post-article-${attrs.id}`,

  defaultState() {
    return { repliesAbove: [] };
  },

  buildId(attrs) {
    return `post_${attrs.post_number}`;
  },

  buildClasses(attrs) {
    if (attrs.via_email) { return 'via-email'; }
  },

  buildAttributes(attrs) {
    return { 'data-post-id': attrs.id, 'data-user-id': attrs.user_id };
  },

  html(attrs, state) {
    const rows = [h('a.tabLoc', { attributes: { href: ''} })];
    if (state.repliesAbove.length) {
      const replies = state.repliesAbove.map(p => this.attach('embedded-post', p, { state: { above: true } }));
      rows.push(h('div.row', h('section.embedded-posts.top.topic-body.offset2', replies)));
    }

    rows.push(h('div.row', [this.attach('post-avatar', attrs),
                            this.attach('post-body', attrs),
                            this.attach('post-gutter', attrs)]));
    return rows;
  },

  toggleReplyAbove() {
    const replyPostNumber = this.attrs.reply_to_post_number;

    // jump directly on mobile
    if (this.attrs.mobileView) {
      DiscourseURL.jumpToPost(replyPostNumber);
      return Ember.RSVP.Promise.resolve();
    }

    if (this.state.repliesAbove.length) {
      this.state.repliesAbove = [];
      return Ember.RSVP.Promise.resolve();
    } else {
      const post = this.findAncestorModel();
      const topicUrl = post ? post.get('topic.url') : null;
      return this.store.find('post-reply-history', { postId: this.attrs.id }).then(posts => {
        this.state.repliesAbove = posts.map((p) => {
          p.shareUrl = `${topicUrl}/${p.post_number}`;
          return transformBasicPost(p);
        });
      });
    }
  },

});

export default createWidget('post', {
  buildKey: attrs => `post-${attrs.id}`,
  shadowTree: true,

  buildClasses(attrs) {
    const classNames = ['topic-post', 'clearfix'];

    if (attrs.selected) { classNames.push('selected'); }
    if (attrs.topicOwner) { classNames.push('topic-owner'); }
    if (attrs.hidden) { classNames.push('post-hidden'); }
    if (attrs.deleted || attrs.user_deleted) { classNames.push('deleted'); }
    if (attrs.primary_group_name) { classNames.push(`group-${attrs.primary_group_name}`); }
    if (attrs.wiki) { classNames.push(`wiki`); }
    if (attrs.isWhisper) { classNames.push('whisper'); }
    if (attrs.isModeratorAction || (attrs.isWarning && attrs.firstPost)) {
      classNames.push('moderator');
    } else {
      classNames.push('regular');
    }
    return classNames;
  },

  html(attrs) {
    return this.attach('post-article', attrs);
  },

  toggleLike() {
    const post = this.model;
    const likeAction = post.get('likeAction');

    if (likeAction && likeAction.get('canToggle')) {
      const promise = likeAction.togglePromise(post);
      this.scheduleRerender();
      return promise;
    }
  },

  undoPostAction(typeId) {
    const post = this.model;
    return post.get('actions_summary').findProperty('id', typeId).undo(post);
  },

  deferPostActionFlags(typeId) {
    const post = this.model;
    return post.get('actions_summary').findProperty('id', typeId).deferFlags(post);
  }
});
