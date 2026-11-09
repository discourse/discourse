import Component from "@glimmer/component";
import { service } from "@ember/service";

/**
 * Renders its block in the mobile tab bar's strip above the tabs, where the
 * current section keeps its views, as the topic lists keep Latest and Top.
 * Renders nothing while the bar is hidden or off, so callers check
 * `mobileTabBar.enabled` only to render their usual navigation instead.
 *
 * @example
 * <MobileTabBarViews>
 *   <ul class="nav-pills">…</ul>
 * </MobileTabBarViews>
 */
export default class MobileTabBarViews extends Component {
  @service mobileTabBar;

  <template>
    {{#if this.mobileTabBar.viewsSlot}}
      {{#in-element this.mobileTabBar.viewsSlot insertBefore=null}}
        {{yield}}
      {{/in-element}}
    {{/if}}
  </template>
}
