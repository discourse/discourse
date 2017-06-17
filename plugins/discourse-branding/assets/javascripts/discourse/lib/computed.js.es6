
/**
  Creates the title property from a SiteSetting. In the future the plan is for
  them to be able to update when changed.
  @method siteTitle
**/
export function siteTitle() {
  return Em.computed(function() {
    return Discourse.SiteSettings['brand_name'] + ' ' + Discourse.SiteSettings['title'];
  }).property();
}
