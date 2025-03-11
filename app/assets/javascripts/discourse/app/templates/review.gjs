import RouteTemplate from "ember-route-template";
import NavItem from "discourse/components/nav-item";

export default RouteTemplate(
  <template>
    <div class="reviewable">
      <ul class="nav nav-pills reviewable-title">
        <NavItem @route="review.index" @label="review.view_all" />
        <NavItem @route="review.topics" @label="review.grouped_by_topic" />
        {{#if @controller.currentUser.admin}}
          <NavItem
            @route="review.settings"
            @label="review.settings.title"
            @icon="wrench"
          />
        {{/if}}
      </ul>

      {{outlet}}
    </div>
  </template>
);
