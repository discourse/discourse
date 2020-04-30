export default {
  shouldRender(_, component) {
    return component.siteSettings.presence_enabled;
  }
};
