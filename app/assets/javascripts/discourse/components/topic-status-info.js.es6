import { bufferedRender } from 'discourse-common/lib/buffered-render';
import Category from 'discourse/models/category';

export default Ember.Component.extend(bufferedRender({
  elementId: 'topic-status-info',
  delayedRerender: null,

  rerenderTriggers: [
    'topic.topic_status_update',
    'topic.topic_status_update.execute_at',
    'topic.topic_status_update.based_on_last_post',
    'topic.topic_status_update.duration',
    'topic.topic_status_update.category_id',
  ],

  buildBuffer(buffer) {
    if (!this.get('topic.topic_status_update.execute_at')) return;

    let statusUpdateAt = moment(this.get('topic.topic_status_update.execute_at'));
    if (statusUpdateAt < new Date()) return;

    let duration = moment.duration(statusUpdateAt - moment());
    let minutesLeft = duration.asMinutes();
    let rerenderDelay = 1000;

    if (minutesLeft > 2160) {
      rerenderDelay = 12 * 60 * 60000;
    } else if (minutesLeft > 1410) {
      rerenderDelay = 60 * 60000;
    } else if (minutesLeft > 90) {
      rerenderDelay = 30 * 60000;
    } else if (minutesLeft > 2) {
      rerenderDelay = 60000;
    }

    let autoCloseHours = this.get("topic.topic_status_update.duration") || 0;

    buffer.push('<h3><i class="fa fa-clock-o"></i> ');

    let options = {
      timeLeft: duration.humanize(true),
      duration: moment.duration(autoCloseHours, "hours").humanize(),
    };

    const categoryId = this.get('topic.topic_status_update.category_id');

    if (categoryId) {
      const category = Category.findById(categoryId);

      options = _.assign({
        categoryName: category.get('slug'),
        categoryUrl: category.get('url')
      }, options);
    }

    buffer.push(I18n.t(this._noticeKey(), options));
    buffer.push('</h3>');

    // TODO Sam: concerned this can cause a heavy rerender loop
    this.set('delayedRerender', Em.run.later(this, this.rerender, rerenderDelay));
  },

  willDestroyElement() {
    if( this.delayedRerender ) {
      Em.run.cancel(this.get('delayedRerender'));
    }
  },

  _noticeKey() {
    const statusType = this.get('topic.topic_status_update.status_type');

    if (this.get("topic.topic_status_update.based_on_last_post")) {
      return `topic.status_update_notice.auto_${statusType}_based_on_last_post`;
    } else {
      return `topic.status_update_notice.auto_${statusType}`;
    }
  }
}));
