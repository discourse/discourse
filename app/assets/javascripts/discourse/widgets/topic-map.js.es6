import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { avatarImg, avatarFor } from 'discourse/widgets/post';
import { dateNode, numberNode } from 'discourse/helpers/node';

const LINKS_SHOWN = 5;

function renderParticipants(userFilters, participants) {
  if (!participants) { return; }

  userFilters = userFilters || [];
  return participants.map(p => {
    return this.attach('topic-participant', p, { state: { toggled: userFilters.contains(p.username) } });
  });
}

createWidget('topic-map-show-links', {
  tagName: 'div.link-summary',
  html(attrs) {
    return h('a', I18n.t('topic_map.links_shown', { totalLinks: attrs.totalLinks }));
  },

  click() {
    this.sendWidgetAction('showAllLinks');
  }
});

createWidget('topic-participant', {
  html(attrs, state) {
    const linkContents = [avatarImg('medium', { username: attrs.username, template: attrs.avatar_template })];

    if (attrs.post_count > 2) {
      linkContents.push(h('span.post-count', attrs.post_count.toString()));
    }

    return h('a.poster.trigger-user-card', {
      className: state.toggled ? 'toggled' : null,
      attributes: { title: attrs.username, 'data-user-card': attrs.username }
    }, linkContents);
  }
});

createWidget('topic-map-summary', {
  tagName: 'section.map',

  buildClasses(attrs, state) {
    if (state.collapsed) { return 'map-collapsed'; }
  },

  html(attrs, state) {
    const contents = [];
    contents.push(h('li',
      [
        h('h4', I18n.t('created_lowercase')),
        avatarFor('tiny', { username: attrs.createdByUsername, template: attrs.createdByAvatarTemplate }),
        dateNode(attrs.topicCreatedAt)
      ]
    ));
    contents.push(h('li',
      h('a', { attributes: { href: attrs.lastPostUrl } }, [
        h('h4', I18n.t('last_reply_lowercase')),
        avatarFor('tiny', { username: attrs.lastPostUsername, template: attrs.lastPostAvatarTemplate }),
        dateNode(attrs.lastPostAt)
      ])
    ));
    contents.push(h('li', [
      numberNode(attrs.topicReplyCount),
      h('h4', I18n.t('replies_lowercase', { count: attrs.topicReplyCount }))
    ]));
    contents.push(h('li.secondary', [
      numberNode(attrs.topicViews, { className: attrs.topicViewsHeat }),
      h('h4', I18n.t('views_lowercase', { count: attrs.topicViews }))
    ]));
    contents.push(h('li.secondary', [
      numberNode(attrs.participantCount),
      h('h4', I18n.t('users_lowercase', { count: attrs.participantCount }))
    ]));

    if (attrs.topicLikeCount) {
      contents.push(h('li.secondary', [
        numberNode(attrs.topicLikeCount),
        h('h4', I18n.t('likes_lowercase', { count: attrs.topicLikeCount }))
      ]));
    }

    if (attrs.topicLinkLength > 0) {
      contents.push(h('li.secondary', [
        numberNode(attrs.topicLinkLength),
        h('h4', I18n.t('links_lowercase', { count: attrs.topicLinkLength }))
      ]));
    }

    if (state.collapsed && attrs.topicPostsCount > 2 && attrs.participants.length > 0) {
      const participants = renderParticipants.call(this, attrs.userFilters, attrs.participants.slice(0, 3));
      contents.push(h('li.avatars', participants));
    }

    return h('ul.clearfix', contents);
  }
});

createWidget('topic-map-link', {
  tagName: 'a.topic-link.track-link',

  buildClasses(attrs) {
    if (attrs.attachment) { return 'attachment'; }
  },

  buildAttributes(attrs) {
    return { href: attrs.url,
             target: "_blank",
             'data-user-id': attrs.user_id,
             'data-ignore-post-id': 'true',
             title: attrs.url };
  },

  html(attrs) {
    if (attrs.title) { return attrs.title; }
    return attrs.url;
  }
});

createWidget('topic-map-expanded', {
  tagName: 'section.topic-map-expanded',
  buildKey: attrs => `topic-map-expanded-${attrs.id}`,

  defaultState() {
    return { allLinksShown: false };
  },

  html(attrs, state) {
    const avatars = h('section.avatars.clearfix', [
      h('h3', I18n.t('topic_map.participants_title')),
      renderParticipants.call(this, attrs.userFilters, attrs.participants)
    ]);

    const result = [avatars];
    if (attrs.topicLinks) {

      const toShow = state.allLinksShown ? attrs.topicLinks : attrs.topicLinks.slice(0, LINKS_SHOWN);
      const links = toShow.map(l => {

        let host = '';
        if (l.title && l.title.length) {
          const domain = l.domain;
          if (domain && domain.length) {
            const s = domain.split('.');
            host = h('span.domain', s[s.length-2] + "." + s[s.length-1]);
          }
        }

        return h('tr', [
          h('td',
            h('span.badge.badge-notification.clicks', {
                attributes: { title: I18n.t('topic_map.clicks', { count: l.clicks }) }
              }, l.clicks.toString())
          ),
          h('td', [this.attach('topic-map-link', l), ' ', host])
        ]);
      });

      const showAllLinksContent = [
        h('h3', I18n.t('topic_map.links_title')),
        h('table.topic-links', links)
      ];

      if (!state.allLinksShown && links.length < attrs.topicLinks.length) {
        showAllLinksContent.push(this.attach('topic-map-show-links', { totalLinks: attrs.topicLinks.length }));
      }

      const section = h('section.links', showAllLinksContent);
      result.push(section);
    }
    return result;
  },

  showAllLinks() {
    this.state.allLinksShown = true;
  }
});

export default createWidget('topic-map', {
  tagName: 'div.topic-map',
  buildKey: attrs => `topic-map-${attrs.id}`,

  defaultState(attrs) {
    return { collapsed: !attrs.hasTopicSummary };
  },

  html(attrs, state) {
    const nav = h('nav.buttons', this.attach('button', {
      title: 'topic.toggle_information',
      icon: state.collapsed ? 'chevron-down' : 'chevron-up',
      action: 'toggleMap',
      className: 'btn',
    }));

    const contents = [nav, this.attach('topic-map-summary', attrs, { state })];

    if (!state.collapsed) {
      contents.push(this.attach('topic-map-expanded', attrs));
    }

    if (attrs.hasTopicSummary) {
      contents.push(this.attach('toggle-topic-summary', attrs));
    }

    if (attrs.showPMMap) {
      contents.push(this.attach('private-message-map', attrs));
    }
    return contents;
  },

  toggleMap() {
    this.state.collapsed = !this.state.collapsed;
  }
});
