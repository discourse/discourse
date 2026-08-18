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
    @hasPendingFilters={{@controller.hasPendingFilters}}
    @hasAppliedFilters={{@controller.hasAppliedFilters}}
    @pendingFilterCount={{@controller.pendingFilterCount}}
    @trafficTypes={{@controller.selectedTrafficTypes}}
    @setPeriod={{@controller.setPeriod}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @toggleFilter={{@controller.toggleFilter}}
    @isFilterSelected={{@controller.isFilterSelected}}
    @toggleTrafficType={{@controller.toggleTrafficType}}
    @removeFilterValue={{@controller.removeFilterValue}}
    @clearFilter={{@controller.clearFilter}}
    @clearAllFilters={{@controller.clearAllFilters}}
    @applyFilters={{@controller.applyFilters}}
    @applyModalFilters={{@controller.applyModalFilters}}
  />
</template>
