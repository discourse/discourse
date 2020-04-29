export default {
  shouldRender(args, component) {
    return (
      component.siteSettings.presence_enabled && args.model.presenceManager
    );
  }
};
