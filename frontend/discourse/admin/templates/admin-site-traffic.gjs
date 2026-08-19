import SiteTrafficExplorer from "discourse/admin/components/site-traffic-explorer";

export default <template>
  <SiteTrafficExplorer
    @traffic={{@controller.traffic}}
    @loading={{@controller.loading}}
    @fetchError={{@controller.fetchError}}
    @hasPageviews={{@controller.hasPageviews}}
    @period={{@controller.safePeriod}}
    @startDate={{@controller.startDate}}
    @endDate={{@controller.endDate}}
    @grouping={{@controller.grouping}}
    @activeFilters={{@controller.activeFilters}}
    @trafficTypes={{@controller.selectedTrafficTypes}}
    @setPeriod={{@controller.setPeriod}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setGrouping={{@controller.setGrouping}}
    @setFilter={{@controller.setFilter}}
    @toggleTrafficType={{@controller.toggleTrafficType}}
    @removeFilter={{@controller.removeFilter}}
  />
</template>
