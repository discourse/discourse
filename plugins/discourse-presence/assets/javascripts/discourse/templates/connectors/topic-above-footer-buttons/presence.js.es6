export default {
  shouldRender(_, ctx) {
    return ctx.siteSettings.presence_enabled;
  }
};
