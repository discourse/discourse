import SiteTrafficExplorer from "discourse/admin/components/site-traffic-explorer";

export default <template>
  <SiteTrafficExplorer
    @activeFilters={{@controller.activeFilters}}
    @applyFilters={{@controller.applyFilters}}
    @applyModalFilters={{@controller.applyModalFilters}}
    @clearAllFilters={{@controller.clearAllFilters}}
    @clearFilter={{@controller.clearFilter}}
    @endDate={{@controller.endDate}}
    @fetchError={{@controller.fetchError}}
    @hasPageviews={{@controller.hasPageviews}}
    @hasPendingFilters={{@controller.hasPendingFilters}}
    @isFilterSelected={{@controller.isFilterSelected}}
    @pendingFilterCount={{@controller.pendingFilterCount}}
    @period={{@controller.safePeriod}}
    @removeFilterValue={{@controller.removeFilterValue}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setPeriod={{@controller.setPeriod}}
    @startDate={{@controller.startDate}}
    @toggleFilter={{@controller.toggleFilter}}
    @toggleTrafficType={{@controller.toggleTrafficType}}
    @traffic={{@controller.traffic}}
    @trafficTypes={{@controller.selectedTrafficTypes}}
  />
</template>
