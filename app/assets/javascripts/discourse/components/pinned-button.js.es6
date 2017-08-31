import { iconHTML } from 'discourse-common/lib/icon-library';
import computed from 'ember-addons/ember-computed-decorators';
import DropdownButton from 'discourse/components/dropdown-button';

export default DropdownButton.extend({
  descriptionKey: 'help',
  classNames: ['pinned-options'],
  title: '',
  buttonExtraClasses: 'btn-icon-text',

  longDescription: function(){
    const topic = this.get('topic');
    const globally = topic.get('pinned_globally') ? '_globally' : '';
    const key = 'topic_statuses.' + (topic.get('pinned') ? 'pinned' + globally : 'unpinned') + '.help';
    return I18n.t(key);
  }.property('topic.pinned'),

  target: Em.computed.alias('topic'),

  hidden: function(){
    const topic = this.get('topic');
    return topic.get('deleted') || (!topic.get('pinned') && !topic.get('unpinned'));
  }.property('topic.pinned', 'topic.deleted', 'topic.unpinned'),

  activeItem: function(){
    return this.get('topic.pinned') ? 'pinned' : 'unpinned';
  }.property('topic.pinned'),

  dropDownContent: function() {
    const globally = this.get('topic.pinned_globally') ? '_globally' : '';
    return [
      {id: 'pinned',
       title: I18n.t('topic_statuses.pinned' + globally + '.title'),
       description: I18n.t('topic_statuses.pinned' + globally + '.help'),
       icon: 'thumb-tack' },
      {id: 'unpinned',
       title: I18n.t('topic_statuses.unpinned.title'),
       description: I18n.t('topic_statuses.unpinned.help'),
       icon: 'thumb-tack',
       iconClass: 'unpinned' }
    ];
  }.property(),

  @computed('topic.pinned', 'topic.pinned_globally')
  text(pinned, pinnedGlobally) {
    const globally = pinnedGlobally ? '_globally' : '';
    const state = pinned ? 'pinned' + globally : 'unpinned';

    const icon = iconHTML(
      'thumb-tack',
      { tagName: 'span', class: (state === 'unpinned' ? 'unpinned' : null) }
    );

    return icon +
      I18n.t('topic_statuses.' + state + '.title') + "<span class='caret'></span>";
  },

  clicked(id) {
    const topic = this.get('topic');
    if(id==='unpinned'){
      topic.clearPin();
    } else {
      topic.rePin();
    }
  }

});
