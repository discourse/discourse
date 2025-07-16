export default {
  shouldRender(args, component) {
    return (
      component.currentUser?.can_assign &&
      args.group.can_show_assigned_tab &&
      args.group.assignment_count > 0
    );
  },
};
