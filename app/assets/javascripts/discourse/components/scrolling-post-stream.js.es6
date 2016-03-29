import DiscourseURL from 'discourse/lib/url';
import { keyDirty } from 'discourse/widgets/widget';
import MountWidget from 'discourse/components/mount-widget';
import { cloak, uncloak } from 'discourse/widgets/post-stream';
import { isWorkaroundActive } from 'discourse/lib/safari-hacks';

function findTopView($posts, viewportTop, min, max) {
  if (max < min) { return min; }

  while(max>min){
    const mid = Math.floor((min + max) / 2);
    const $post = $($posts[mid]);
    const viewBottom = $post.position().top + $post.height();

    if (viewBottom > viewportTop) {
      max = mid-1;
    } else {
      min = mid+1;
    }
  }

  return min;
}

export default MountWidget.extend({
  widget: 'post-stream',
  _topVisible: null,
  _bottomVisible: null,

  args: Ember.computed(function() {
    return this.getProperties('posts',
                              'canCreatePost',
                              'multiSelect',
                              'gaps',
                              'selectedQuery',
                              'selectedPostsCount',
                              'searchService');
  }).volatile(),

  scrolled() {
    if (this.isDestroyed || this.isDestroying) { return; }
    if (isWorkaroundActive()) { return; }

    const $w = $(window);
    const windowHeight = window.innerHeight ? window.innerHeight : $w.height();
    const slack = Math.round(windowHeight * 5);
    const onscreen = [];
    const nearby = [];

    let windowTop = $w.scrollTop();

    const $posts = this.$('.onscreen-post, .cloaked-post');
    const viewportTop = windowTop - slack;
    const topView = findTopView($posts, viewportTop, 0, $posts.length-1);

    let windowBottom = windowTop + windowHeight;
    let viewportBottom = windowBottom + slack;

    const bodyHeight = $('body').height();
    if (windowBottom > bodyHeight) { windowBottom = bodyHeight; }
    if (viewportBottom > bodyHeight) { viewportBottom = bodyHeight; }

    let bottomView = topView;
    while (bottomView < $posts.length) {
      const post = $posts[bottomView];
      const $post = $(post);

      if (!$post) { break; }

      const viewTop = $post.offset().top;
      const viewBottom = viewTop + $post.height() + 100;

      if (viewTop > viewportBottom) { break; }

      if (viewBottom > windowTop && viewTop <= windowBottom) {
        onscreen.push(bottomView);
      }
      nearby.push(bottomView);

      bottomView++;
    }

    const posts = this.posts;
    const refresh = cb => this.queueRerender(cb);
    if (onscreen.length) {
      const first = posts.objectAt(onscreen[0]);
      if (this._topVisible !== first) {
        this._topVisible = first;
        const $body = $('body');
        const elem = $posts[onscreen[0]];
        const elemId = elem.id;
        const $elem = $(elem);
        const elemPos = $elem.position();
        const distToElement = elemPos ? $body.scrollTop() - elemPos.top : 0;

        const topRefresh = () => {
          refresh(() => {
            const $refreshedElem = $(`#${elemId}`);

            // Quickly going back might mean the element is destroyed
            const position = $refreshedElem.position();
            if (position && position.top) {
              $('html, body').scrollTop(position.top + distToElement);
            }
          });
        };
        this.sendAction('topVisibleChanged', { post: first, refresh: topRefresh });
      }

      const last = posts.objectAt(onscreen[onscreen.length-1]);
      if (this._bottomVisible !== last) {
        this._bottomVisible = last;
        this.sendAction('bottomVisibleChanged', { post: last, refresh });
      }
    } else {
      this._topVisible = null;
      this._bottomVisible = null;
    }

    const onscreenPostNumbers = [];
    const prev = this._previouslyNearby;
    const newPrev = {};
    nearby.forEach(idx => {
      const post = posts.objectAt(idx);
      const postNumber = post.post_number;
      delete prev[postNumber];

      if (onscreen.indexOf(idx) !== -1) {
        onscreenPostNumbers.push(postNumber);
      }
      newPrev[postNumber] = post;
      uncloak(post, this);
    });

    Object.keys(prev).forEach(pn => cloak(prev[pn], this));

    this._previouslyNearby = newPrev;
    this.screenTrack.setOnscreen(onscreenPostNumbers);
  },

  _scrollTriggered() {
    Ember.run.scheduleOnce('afterRender', this, this.scrolled);
  },

  didInsertElement() {
    this._super();
    const debouncedScroll = () => Ember.run.debounce(this, this._scrollTriggered, 10);

    this._previouslyNearby = {};

    this.appEvents.on('post-stream:refresh', debouncedScroll);
    $(document).bind('touchmove.post-stream', debouncedScroll);
    $(window).bind('scroll.post-stream', debouncedScroll);
    this._scrollTriggered();

    this.appEvents.on('post-stream:posted', staged => {
      const disableJumpReply = this.currentUser.get('disable_jump_reply');

      this.queueRerender(() => {
        if (staged && !disableJumpReply) {
          const postNumber = staged.get('post_number');
          DiscourseURL.jumpToPost(postNumber, { skipIfOnScreen: true });
        }
      });
    });

    this.$().on('mouseenter.post-stream', 'button.widget-button', e => {
      $('button.widget-button').removeClass('d-hover');
      $(e.target).addClass('d-hover');
    });

    this.$().on('mouseleave.post-stream', 'button.widget-button', () => {
      $('button.widget-button').removeClass('d-hover');
    });

    this.appEvents.on('post-stream:refresh', args => {
      if (args) {
        if (args.id) {
          keyDirty(`post-${args.id}`);

          if (args.refreshLikes) {
            keyDirty(`post-menu-${args.id}`, { onRefresh: 'refreshLikes' });
          }
        } else if (args.force) {
          keyDirty(`*`);
        }
      }
      this.queueRerender();
    });
  },

  willDestroyElement() {
    this._super();
    $(document).unbind('touchmove.post-stream');
    $(window).unbind('scroll.post-stream');
    this.appEvents.off('post-stream:refresh');
    this.$().off('mouseenter.post-stream');
    this.$().off('mouseleave.post-stream');
    this.appEvents.off('post-stream:refresh');
    this.appEvents.off('post-stream:posted');
  }

});
