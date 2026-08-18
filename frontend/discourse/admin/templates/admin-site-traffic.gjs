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
    @parentStartDate={{@controller.parentStartDate}}
    @parentEndDate={{@controller.parentEndDate}}
    @hasPreciseRange={{@controller.hasPreciseRange}}
    @browserTimezone={{@controller.browserTimezone}}
    @grouping={{@controller.grouping}}
    @activeFilters={{@controller.activeFilters}}
    @trafficTypes={{@controller.selectedTrafficTypes}}
    @setPeriod={{@controller.setPeriod}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setPreciseRange={{@controller.setPreciseRange}}
    @clearPreciseRange={{@controller.clearPreciseRange}}
    @setGrouping={{@controller.setGrouping}}
    @setFilter={{@controller.setFilter}}
    @toggleTrafficType={{@controller.toggleTrafficType}}
    @removeFilter={{@controller.removeFilter}}
  />
</template>
