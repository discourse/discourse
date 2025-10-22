import RouteTemplate from "ember-route-template";
import FilterNavigation from "discourse/components/discovery/filter-navigation";
import Layout from "discourse/components/discovery/layout";
import Topics from "discourse/components/discovery/topics";

export default RouteTemplate(
  <template>
    <Layout @model={{@controller.model}} @listClass="--filter --topic-list">
      <:navigation>
        <FilterNavigation
          @queryString={{@controller.q}}
          @updateTopicsListQueryParams={{@controller.updateTopicsListQueryParams}}
          @canBulkSelect={{@controller.canBulkSelect}}
          @bulkSelectHelper={{@controller.bulkSelectHelper}}
          @tips={{@controller.model.topic_list.filter_option_info}}
        />
      </:navigation>
      <:list>
        <Topics
          @period={{@controller.period}}
          @expandAllPinned={{@controller.expandAllPinned}}
          @expandAllGloballyPinned={{@controller.expandAllGloballyPinned}}
          @model={{@controller.model}}
          @canBulkSelect={{@controller.canBulkSelect}}
          @bulkSelectHelper={{@controller.bulkSelectHelper}}
        />
      </:list>
    </Layout>
  </template>
);
