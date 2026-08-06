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
    @activeFilters={{@controller.activeFilters}}
    @setPeriod={{@controller.setPeriod}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setFilter={{@controller.setFilter}}
    @removeFilter={{@controller.removeFilter}}
    @clearFilters={{@controller.clearFilters}}
    @retry={{@controller.fetchTraffic}}
  />
</template>
