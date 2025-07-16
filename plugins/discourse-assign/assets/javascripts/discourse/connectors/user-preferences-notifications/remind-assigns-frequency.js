export default {
  shouldRender(args, component) {
    return component.currentUser?.can_assign;
  },
};
