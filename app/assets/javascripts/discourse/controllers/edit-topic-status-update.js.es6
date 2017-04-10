import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import TopicStatusUpdate from 'discourse/models/topic-status-update';
import { popupAjaxError } from 'discourse/lib/ajax-error';

const CLOSE_STATUS_TYPE = 'close';
const OPEN_STATUS_TYPE = 'open';
const PUBLISH_TO_CATEGORY_STATUS_TYPE = 'publish_to_category';

export default Ember.Controller.extend(ModalFunctionality, {
  closeStatusType: CLOSE_STATUS_TYPE,
  openStatusType: OPEN_STATUS_TYPE,
  publishToCategoryStatusType: PUBLISH_TO_CATEGORY_STATUS_TYPE,
  updateTimeValid: null,
  updateTimeInvalid: Em.computed.not('updateTimeValid'),
  loading: false,
  updateTime: null,
  topicStatusUpdate: Ember.computed.alias("model.topic_status_update"),
  selection: Ember.computed.alias('model.topic_status_update.status_type'),
  autoOpen: Ember.computed.equal('selection', OPEN_STATUS_TYPE),
  autoClose: Ember.computed.equal('selection', CLOSE_STATUS_TYPE),
  publishToCategory: Ember.computed.equal('selection', PUBLISH_TO_CATEGORY_STATUS_TYPE),

  @computed('autoClose', 'updateTime')
  disableAutoClose(autoClose, updateTime) {
    return updateTime && !autoClose;
  },

  @computed('autoOpen', 'updateTime')
  disableAutoOpen(autoOpen, updateTime) {
    return updateTime && !autoOpen;
  },

  @computed('publishToCatgory', 'updateTime')
  disablePublishToCategory(publishToCatgory, updateTime) {
    return updateTime && !publishToCatgory;
  },

  @computed('topicStatusUpdate.based_on_last_post', 'updateTime', 'model.last_posted_at')
  willCloseImmediately(basedOnLastPost, updateTime, lastPostedAt) {
    if (!basedOnLastPost) {
      return false;
    }
    const closeDate = new Date(lastPostedAt);
    closeDate.setHours(closeDate.getHours() + updateTime);
    return closeDate < new Date();
  },

  @computed('topicStatusUpdate.based_on_last_post', 'model.last_posted_at')
  willCloseI18n(basedOnLastPost, lastPostedAt) {
    if (basedOnLastPost) {
      const diff = Math.round((new Date() - new Date(lastPostedAt)) / (1000*60*60));
      return I18n.t('topic.auto_close_immediate', { count: diff });
    }
  },

  @computed('updateTime', 'updateTimeInvalid', 'loading')
  saveDisabled(updateTime, updateTimeInvalid, loading) {
    return Ember.isEmpty(updateTime) || updateTimeInvalid || loading;
  },

  @computed("model.visible")
  excludeCategoryId(visible) {
    if (visible) return this.get('model.category_id');
  },

  @observes("topicStatusUpdate.execute_at", "topicStatusUpdate.duration")
  _setUpdateTime() {
    let time = null;

    if (this.get("topicStatusUpdate.based_on_last_post")) {
      time = this.get("topicStatusUpdate.duration");
    } else if (this.get("topicStatusUpdate.execute_at")) {
      const closeTime = new Date(this.get("topicStatusUpdate.execute_at"));

      if (closeTime > new Date()) {
        time = moment(closeTime).format("YYYY-MM-DD HH:mm");
      }
    }

    this.set("updateTime", time);
  },

  _setStatusUpdate(time, status_type) {
    this.set('loading', true);

    TopicStatusUpdate.updateStatus(
      this.get('model.id'),
      time,
      this.get('topicStatusUpdate.based_on_last_post'),
      status_type,
      this.get('categoryId')
    ).then(result => {
      if (time) {
        this.send('closeModal');

        this.get("topicStatusUpdate").setProperties({
          execute_at: result.execute_at,
          duration: result.duration,
          category_id: result.category_id
        });

        this.set('model.closed', result.closed);
      } else {
        this.set('topicStatusUpdate', Ember.Object.create({}));
        this.set('selection', null);
      }
    }).catch(error => {
      popupAjaxError(error);
    }).finally(() => this.set('loading', false));
  },

  actions: {
    saveStatusUpdate() {
      this._setStatusUpdate(this.get("updateTime"), this.get('selection'));
    },

    removeStatusUpdate() {
      this._setStatusUpdate(null, this.get('selection'));
    }
  }
});
