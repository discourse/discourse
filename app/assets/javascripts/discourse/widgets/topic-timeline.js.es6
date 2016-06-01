import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { relativeAge } from 'discourse/lib/formatter';
import { iconNode } from 'discourse/helpers/fa-icon';

const SCROLLAREA_HEIGHT = 300;
const SCROLLER_HEIGHT = 50;
const SCROLLAREA_REMAINING = SCROLLAREA_HEIGHT - SCROLLER_HEIGHT;

function clamp(p, min=0.0, max=1.0) {
  return Math.max(Math.min(p, max), min);
}

createWidget('timeline-last-read', {
  tagName: 'div.timeline-last-read',

  buildAttributes(attrs) {
    return { style: `height: 40px; top: ${attrs.top}px` };
  },

  html() {
    return [
      iconNode('circle', { class: 'progress' }),
      this.attach('button', {
        className: 'btn btn-primary btn-small',
        label: 'topic.timeline.back',
        title: 'topic.timeline.back_description',
        action: 'goBack'
      })
    ];
  },

  goBack() {
    this.sendWidgetAction('jumpToPost', this.attrs.lastRead);
  }
});

function timelineDate(date) {
  const fmt = (date.getFullYear() === new Date().getFullYear()) ?  'long_no_year_no_time' : 'timeline_date';
  return moment(date).format(I18n.t(`dates.${fmt}`));
}

createWidget('timeline-scroller', {
  tagName: 'div.timeline-scroller',

  buildAttributes() {
    return { style: `height: ${SCROLLER_HEIGHT}px` };
  },

  html(attrs) {
    const { current, total, date } = attrs;

    const contents = [
      h('div.timeline-replies', I18n.t(`topic.timeline.replies_short`, { current, total }))
    ];

    if (date) {
      contents.push(h('div.timeline-ago', timelineDate(date)));
    }

    return [ h('div.timeline-handle'), h('div.timeline-scroller-content', contents) ];
  },

  drag(e) {
    this.sendWidgetAction('updatePercentage', e.pageY);
  },

  dragEnd() {
    this.sendWidgetAction('commit');
  }
});

createWidget('timeline-padding', {
  tagName: 'div.timeline-padding',
  buildAttributes(attrs) {
    return { style: `height: ${attrs.height}px` };
  },

  click(e) {
    this.sendWidgetAction('updatePercentage', e.pageY);
    this.sendWidgetAction('commit');
  }
});

createWidget('timeline-scrollarea', {
  tagName: 'div.timeline-scrollarea',
  buildKey: () => `timeline-scrollarea`,

  buildAttributes() {
    return { style: `height: ${SCROLLAREA_HEIGHT}px` };
  },

  defaultState(attrs) {
    return { percentage: this._percentFor(attrs.topic, attrs.enteredIndex + 1), scrolledPost: 1 };
  },

  position() {
    const { attrs } = this;
    const percentage = this.state.percentage;
    const topic = attrs.topic;
    const postStream = topic.get('postStream');
    const total = postStream.get('filteredPostsCount');

    const current = clamp(Math.floor(total * percentage) + 1, 1, total);

    const daysAgo = postStream.closestDaysAgoFor(current);
    const date = new Date();
    date.setDate(date.getDate() - daysAgo || 0);

    const result = {
      current,
      total,
      date,
      lastRead: null,
      lastReadPercentage: null
    };

    const lastReadId = topic.last_read_post_id;
    const lastReadNumber = topic.last_read_post_number;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.get('stream').indexOf(lastReadId) + 1;
      result.lastRead = idx;
      result.lastReadPercentage = this._percentFor(topic, idx);
    }

    return result;
  },

  html(attrs, state) {
    const position = this.position();

    state.scrolledPost = position.current;
    const percentage = state.percentage;
    if (percentage === null) { return; }

    const before = SCROLLAREA_REMAINING * percentage;
    const after = (SCROLLAREA_HEIGHT - before) - SCROLLER_HEIGHT;

    const result = [
      this.attach('timeline-padding', { height: before }),
      this.attach('timeline-scroller', position),
      this.attach('timeline-padding', { height: after })
    ];

    if (position.lastRead && position.lastRead < attrs.topic.posts_count) {
      const lastReadTop = Math.round(position.lastReadPercentage * SCROLLAREA_HEIGHT);
      if (lastReadTop > (before + SCROLLER_HEIGHT)) {
        result.push(this.attach('timeline-last-read', { top: lastReadTop, lastRead: position.lastRead }));
      }
    }

    return result;
  },

  updatePercentage(y) {
    const $area = $('.timeline-scrollarea');
    const areaTop = $area.offset().top;

    const percentage = clamp(parseFloat(y - areaTop) / $area.height());

    this.state.percentage = percentage;
  },

  commit() {
    const position = this.position();
    this.state.scrolledPost = position.current;

    this.sendWidgetAction('jumpToIndex', position.current);
  },

  topicCurrentPostScrolled(event) {
    this.state.percentage = event.percent;
  },

  _percentFor(topic, postIndex) {
    const total = topic.get('postStream.filteredPostsCount');
    return clamp(parseFloat(postIndex - 1.0) / total);
  }
});

createWidget('topic-timeline-container', {
  tagName: 'div.timeline-container',
  buildClasses(attrs) {
    if (attrs.dockAt) {
      const result = ['timeline-docked'];
      if (attrs.dockBottom) {
        result.push('timeline-docked-bottom');
      }
      return result.join(' ');
    }
  },

  buildAttributes(attrs) {
    return { style: `top: ${attrs.top}px` };
  },

  html(attrs) {
    return this.attach('topic-timeline', attrs);
  }
});

export default createWidget('topic-timeline', {
  tagName: 'div.topic-timeline',

  html(attrs) {
    const { topic } = attrs;
    const createdAt = new Date(topic.created_at);
    const stream = attrs.topic.get('postStream.stream');
    const { currentUser } = this;

    if (stream.length < 3) { return; }


    let result = [];
    if (currentUser && currentUser.get('canManageTopic')) {
      result.push(h('div.timeline-controls', this.attach('topic-admin-menu-button', { topic })));
    }

    const bottomAge = relativeAge(new Date(topic.last_posted_at), { addAgo: true, defaultFormat: timelineDate });
    result = result.concat([this.attach('link', {
                              className: 'start-date',
                              rawLabel: timelineDate(createdAt),
                              action: 'jumpTop'
                            }),
                            this.attach('timeline-scrollarea', attrs),
                            this.attach('link', {
                              className: 'now-date',
                              rawLabel: bottomAge,
                              action: 'jumpBottom'
                            })]);

    if (currentUser) {
      const controls = [];
      if (attrs.topic.get('details.can_create_post')) {
        controls.push(this.attach('button', {
          className: 'btn btn-primary create',
          icon: 'reply',
          label: 'topic.reply.title',
          title: 'topic.reply.help',
          action: 'replyToPost'
        }));
      }

      if (currentUser) {
        controls.push(this.attach('topic-notifications-button', { topic }));
      }
      result.push(h('div.timeline-footer-controls', controls));
    }

    return result;
  }
});
