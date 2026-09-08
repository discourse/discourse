import FilterNavigation from "discourse/components/discovery/filter-navigation";
import Layout from "discourse/components/discovery/layout";
import Topics from "discourse/components/discovery/topics";

export default <template>
  <Layout @listClass="--filter --topic-list" @model={{@controller.model}}>
    <:navigation>
      <FilterNavigation
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @queryString={{@controller.q}}
        @tips={{@controller.model.topic_list.filter_option_info}}
        @updateTopicsListQueryParams={{@controller.updateTopicsListQueryParams}}
      />
    </:navigation>
    <:list>
      <Topics
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @expandAllGloballyPinned={{@controller.expandAllGloballyPinned}}
        @expandAllPinned={{@controller.expandAllPinned}}
        @model={{@controller.model}}
        @period={{@controller.period}}
      />
    </:list>
  </Layout>
</template>
