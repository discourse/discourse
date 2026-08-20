import SiteTrafficExplorer from "discourse/admin/components/site-traffic-explorer";

export default <template>
  <SiteTrafficExplorer
    @traffic={{@controller.traffic}}
    @fetchError={{@controller.fetchError}}
    @hasPageviews={{@controller.hasPageviews}}
    @period={{@controller.safePeriod}}
    @startDate={{@controller.startDate}}
    @endDate={{@controller.endDate}}
    @activeFilters={{@controller.activeFilters}}
    @trafficTypes={{@controller.selectedTrafficTypes}}
    @setPeriod={{@controller.setPeriod}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setFilter={{@controller.setFilter}}
    @toggleTrafficType={{@controller.toggleTrafficType}}
    @removeFilter={{@controller.removeFilter}}
  />
</template>
