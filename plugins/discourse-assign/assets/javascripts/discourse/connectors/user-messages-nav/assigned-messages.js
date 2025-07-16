export function shouldShowAssigned(args, component) {
  const needsButton = component.currentUser?.can_assign;
  return (
    needsButton && (!component.site.mobileView || args.model.isPrivateMessage)
  );
}

export default {
  shouldRender(args, component) {
    return shouldShowAssigned(args, component);
  },
};
