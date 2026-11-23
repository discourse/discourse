import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";

export default class ReviewableNav extends Component {
  @service currentUser;

  <template>
    <DHorizontalOverflowNav class="reviewable-title" @ariaLabel="Review">
      <DNavItem @label="review.view_all" @route="review.index" />
      <DNavItem @label="review.grouped_by_topic" @route="review.topics" />
      <PluginOutlet @name="review-nav-items" />
      {{#if this.currentUser.admin}}
        <DNavItem
          @icon="wrench"
          @label="review.settings.title"
          @route="review.settings"
        />
      {{/if}}
    </DHorizontalOverflowNav>
  </template>
}
