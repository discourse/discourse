export default {
  setupComponent(args, component) {
    component.set('choices', ['latest', 'new', 'unread', 'top', 'latest-mobile', 'new-mobile', 'unread-mobile', 'top-mobile']);
  }
};
