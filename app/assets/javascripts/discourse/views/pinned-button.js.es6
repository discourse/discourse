import DropdownButtonView from 'discourse/views/dropdown-button';

export default DropdownButtonView.extend({
  descriptionKey: 'help',
  classNames: ['pinned-options'],
  title: '',
  longDescription: function(){
    var topic = this.get('topic');
    var globally = topic.get('pinned_globally') ? '_globally' : '';

    var key = 'topic_statuses.' + (topic.get('pinned') ? 'pinned' + globally : 'unpinned') + '.help';
    return I18n.t(key);
  }.property('topic.pinned'),

  topic: Em.computed.alias('controller.model'),
  target: Em.computed.alias('topic'),

  hidden: function(){
    var topic = this.get('topic');
    return topic.get('deleted') || (!topic.get('pinned') && !topic.get('unpinned'));
  }.property('topic.pinned', 'topic.deleted', 'topic.unpinned'),

  activeItem: function(){
    return this.get('topic.pinned') ? 'pinned' : 'unpinned';
  }.property('topic.pinned'),

  dropDownContent: function() {
    var globally = this.get('topic.pinned_globally') ? '_globally' : '';
    return [
      {id: 'pinned',
       title: I18n.t('topic_statuses.pinned' + globally + '.title'),
       description: I18n.t('topic_statuses.pinned' + globally + '.help'),
       styleClasses: 'fa fa-thumb-tack' },
      {id: 'unpinned',
       title: I18n.t('topic_statuses.unpinned.title'),
       description: I18n.t('topic_statuses.unpinned.help'),
       styleClasses: 'fa fa-thumb-tack unpinned' }
    ];
  }.property(),

  text: function() {
    var globally = this.get('topic.pinned_globally') ? '_globally' : '';
    var state = this.get('topic.pinned') ? 'pinned' + globally : 'unpinned';

    return '<span class="fa fa-thumb-tack' + (state === 'unpinned' ? ' unpinned' : "") +  '"></span> ' +
      I18n.t('topic_statuses.' + state + '.title') + "<span class='caret'></span>";
  }.property('topic.pinned', 'topic.unpinned'),

  clicked: function(id) {
    var topic = this.get('topic');
    if(id==='unpinned'){
      topic.clearPin();
    } else {
      topic.rePin();
    }
  }

});
