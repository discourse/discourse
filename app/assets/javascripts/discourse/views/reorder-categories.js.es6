import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  title: I18n.t('categories.reorder.title'),
  templateName: 'modal/reorder-categories',

  _setup: function() {
    this.get('controller').on('scrollIntoView', this, this.scrollIntoView);
  }.on('didInsertElement'),
  _teardown: function() {
    this.get('controller').off('scrollIntoView', this, this.scrollIntoView);
    this.set('prevScrollElem', null);
  }.on('willClearRender'),

  scrollIntoView() {
    const elem = this.$('tr[data-category-id="' + this.get('controller.scrollIntoViewId') + '"]');
    const scrollParent = this.$('.modal-body');
    const eoff = elem.position();
    const poff = $(document.getElementById('rc-scroll-anchor')).position();
    const currHeight = scrollParent.height();

    elem[0].className = "highlighted";

    const goal = eoff.top - poff.top - currHeight / 2,
      current = scrollParent.scrollTop();
    scrollParent.scrollTop(9999999);
    const max = scrollParent.scrollTop();
    scrollParent.scrollTop(current);

    const doneTimeout = setTimeout(function() {
      elem[0].className = "highlighted done";
      setTimeout(function() {
        elem[0].className = "";
      }, 2000);
    }, 0);

    if (goal > current - currHeight / 4 && goal < current + currHeight / 4) {
      // Too close to goal
      return;
    }
    if (max - current < 10 && goal > current) {
      // Too close to bottom
      return;
    }
    if (current < 10 && goal < current) {
      // Too close to top
      return;
    }

    if (!window.requestAnimationFrame) {
      scrollParent.scrollTop(goal);
    } else {
      clearTimeout(doneTimeout);
      const startTime = performance.now();
      const duration = 100;

      function doScroll(timestamp) {
        let progress = (timestamp - startTime) / duration;
        if (progress > 1) {
          progress = 1;
          setTimeout(function() {
            elem[0].className = "highlighted done";
            setTimeout(function() {
              elem[0].className = "";
            }, 2000);
          }, 0);
        } else if (progress < 0) {
          progress = 0;
        }
        if (progress < 1) {
          window.requestAnimationFrame(doScroll);
        }

        const iprogress = 1 - progress;
        scrollParent.scrollTop(goal * progress + current * iprogress);
      }
      window.requestAnimationFrame(doScroll);
    }
  }
});
