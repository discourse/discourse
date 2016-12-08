import MountWidget from 'discourse/components/mount-widget';

export default MountWidget.extend({
  tagName: 'span',
  widget: "topic-admin-menu-button",

  buildArgs() {
    return this.getProperties('topic', 'fixed', 'openUpwards');
  }
});
