import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { relativeAge } from 'discourse/lib/formatter';
import { iconNode } from 'discourse/helpers/fa-icon-node';
import RawHtml from 'discourse/widgets/raw-html';

const SCROLLAREA_HEIGHT = 300;
const SCROLLER_HEIGHT = 50;
const SCROLLAREA_REMAINING = SCROLLAREA_HEIGHT - SCROLLER_HEIGHT;
const LAST_READ_HEIGHT = 20;

function clamp(p, min=0.0, max=1.0) {
  return Math.max(Math.min(p, max), min);
}

function attachBackButton(widget) {
  return widget.attach('button', {
    className: 'btn btn-primary btn-small back-button',
    label: 'topic.timeline.back',
    title: 'topic.timeline.back_description',
    action: 'goBack'
  });
}

createWidget('timeline-last-read', {
  tagName: 'div.timeline-last-read',

  buildAttributes(attrs) {
    const bottom = SCROLLAREA_HEIGHT - (LAST_READ_HEIGHT / 2);
    const top = attrs.top > bottom ? bottom : attrs.top;
    return { style: `height: ${LAST_READ_HEIGHT}px; top: ${top}px` };
  },

  html(attrs) {
    const result = [ iconNode('minus', { class: 'progress' }) ];
    if (attrs.showButton) {
      result.push(attachBackButton(this));
    }

    return result;
  },

});

function timelineDate(date) {
  const fmt = (date.getFullYear() === new Date().getFullYear()) ?  'long_no_year_no_time' : 'timeline_date';
  return moment(date).format(I18n.t(`dates.${fmt}`));
}

createWidget('timeline-scroller', {
  tagName: 'div.timeline-scroller',
  buildKey: () => `timeline-scroller`,

  defaultState() {
    return { dragging: false };
  },

  buildAttributes() {
    return { style: `height: ${SCROLLER_HEIGHT}px` };
  },

  html(attrs, state) {
    const { current, total, date } = attrs;

    const contents = [
      h('div.timeline-replies', I18n.t(`topic.timeline.replies_short`, { current, total }))
    ];

    if (date) {
      contents.push(h('div.timeline-ago', timelineDate(date)));
    }

    if (attrs.showDockedButton && !state.dragging) {
      contents.push(attachBackButton(this));
    }
    let result = [ h('div.timeline-handle'), h('div.timeline-scroller-content', contents) ];

    if (attrs.fullScreen) {
      result = [result[1], result[0]];
    }

    return result;
  },

  drag(e) {
    this.state.dragging = true;
    this.sendWidgetAction('updatePercentage', e.pageY);
  },

  dragEnd(e) {
    this.state.dragging = false;
    if ($(e.target).is('button')) {
      this.sendWidgetAction('goBack');
    } else {
      this.sendWidgetAction('commit');
    }
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


    if (this.state.position !== result.current) {
      this.state.position = result.current;
      const timeline = this._findAncestorWithProperty('updatePosition');
      timeline.updatePosition.call(timeline, result.current);
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

    let showButton = false;
    const hasBackPosition =
      position.lastRead > 3 &&
      Math.abs(position.lastRead - position.current) > 3 &&
      Math.abs(position.lastRead - position.total) > 1 &&
      (position.lastRead && position.lastRead !== position.total);

    if (hasBackPosition) {
      const lastReadTop = Math.round(position.lastReadPercentage * SCROLLAREA_HEIGHT);
      showButton = ((before + SCROLLER_HEIGHT - 5) < lastReadTop) ||
                    (before > (lastReadTop + 25));


      // Don't show if at the bottom of the timeline
      if (lastReadTop > (SCROLLAREA_HEIGHT - (LAST_READ_HEIGHT / 2))) {
        showButton = false;
      }
    }

    const result = [
      this.attach('timeline-padding', { height: before }),
      this.attach('timeline-scroller', _.merge(position, {
        showDockedButton: !attrs.mobileView && hasBackPosition && !showButton,
        fullScreen: attrs.fullScreen
      })),
      this.attach('timeline-padding', { height: after })
    ];

    if (hasBackPosition) {
      const lastReadTop = Math.round(position.lastReadPercentage * SCROLLAREA_HEIGHT);
      result.push(this.attach('timeline-last-read', {
        top: lastReadTop,
        lastRead: position.lastRead,
        showButton
      }));
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
  },

  goBack() {
    this.sendWidgetAction('jumpToIndex', this.position().lastRead);
  }
});

createWidget('topic-timeline-container', {
  tagName: 'div.timeline-container',
  buildClasses(attrs) {
    if (attrs.fullScreen) {
      if (attrs.addShowClass) {
        return 'timeline-fullscreen show';
      } else {
        return 'timeline-fullscreen';
      }
    }
    if (attrs.dockAt) {
      const result = ['timeline-docked'];
      if (attrs.dockBottom) {
        result.push('timeline-docked-bottom');
      }
      return result.join(' ');
    }
  },

  buildAttributes(attrs) {
    if (attrs.top) {
      return { style: `top: ${attrs.top}px` };
    }
  },

  html(attrs) {
    return this.attach('topic-timeline', attrs);
  }
});

export default createWidget('topic-timeline', {
  tagName: 'div.topic-timeline',

  buildKey: () => 'topic-timeline-area',

  defaultState() {
    return { position: null, excerpt: null };
  },

  updatePosition(pos) {
    if (!this.attrs.fullScreen) {
      return;
    }

    this.state.position = pos;
    this.state.excerpt = "";
    this.scheduleRerender();

    const stream = this.attrs.topic.get('postStream');

    // a little debounce to avoid flashing
    setTimeout(()=>{
      if (!this.state.position === pos) {
        return;
      }

      // we have an off by one, stream is zero based,
      // pos is 1 based
      stream.excerpt(pos-1).then(info => {

        if (info && this.state.position === pos) {
          let excerpt = "";

          if (info.username) {
            excerpt = "<span class='username'>" + info.username + ":</span> ";
          }

          excerpt += info.excerpt;

          this.state.excerpt = excerpt;
          this.scheduleRerender();
        }
      });
    }, 50);
  },

  html(attrs) {
    const { topic } = attrs;
    const createdAt = new Date(topic.created_at);
    const stream = attrs.topic.get('postStream.stream');
    const { currentUser } = this;

    let result = [];

    if (attrs.fullScreen) {
      let titleHTML = "";
      if (attrs.mobileView) {
        titleHTML = new RawHtml({ html: `<span>${topic.get('fancyTitle')}</span>` });
      }

      let elems = [h('h2', this.attach('link', {
              contents: ()=>titleHTML,
              className: 'fancy-title',
              action: 'jumpTop'}))];


      if (this.state.excerpt) {
        elems.push(
            new RawHtml({
              html: "<div class='post-excerpt'>" + this.state.excerpt + "</div>"
            }));
      }

      result.push(h('div.title', elems));
    }


    if (!attrs.fullScreen && currentUser && currentUser.get('canManageTopic')) {
      result.push(h('div.timeline-controls', this.attach('topic-admin-menu-button', { topic })));
    }

    if (stream.length < 3) {
      return result;
    }

    const bottomAge = relativeAge(new Date(topic.last_posted_at), { addAgo: true, defaultFormat: timelineDate });
    let scroller = [h('div.timeline-date-wrapper', this.attach('link', {
                              className: 'start-date',
                              rawLabel: timelineDate(createdAt),
                              action: 'jumpTop'
                            })),
                            this.attach('timeline-scrollarea', attrs),
                            h('div.timeline-date-wrapper', this.attach('link', {
                              className: 'now-date',
                              rawLabel: bottomAge,
                              action: 'jumpBottom'
                            }))];

    result = result.concat([h('div.timeline-scrollarea-wrapper', scroller)]);

    const controls = [];
    if (currentUser && !attrs.fullScreen) {
      if (attrs.topic.get('details.can_create_post')) {
        controls.push(this.attach('button', {
          className: 'btn create',
          icon: 'reply',
          title: 'topic.reply.help',
          action: 'replyToPost'
        }));
      }

    }

    if (attrs.fullScreen) {
      controls.push(this.attach('button', {
        className: 'btn jump-to-post',
        title: 'topic.progress.jump_prompt_long',
        label: 'topic.progress.jump_prompt',
        action: 'jumpToPostPrompt'
      }));
    }

    if (currentUser) {
      controls.push(this.attach('topic-notifications-button', { topic }));
    }

    if (controls.length > 0) {
      result.push(h('div.timeline-footer-controls', controls));
    }

    return result;
  }
});
