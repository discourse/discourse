import RedesignedAdminDashboard from "discourse/admin/components/redesigned-admin-dashboard";

export default <template>
  <RedesignedAdminDashboard
    @loadedSections={{@controller.loadedSections}}
    @loadingSections={{@controller.loadingSections}}
    @onIgnoreProblem={{@controller.ignoreProblem}}
    @onRefreshProblems={{@controller.refreshSiteAdvice}}
    @problems={{@controller.problems}}
    @refreshSections={{@controller.fetchSections}}
    @reorderSections={{@controller.reorderSections}}
    @requestedEndDate={{@controller.endDate}}
    @requestedPeriod={{@controller.safePeriod}}
    @requestedStartDate={{@controller.startDate}}
    @sectionsFetchError={{@controller.sectionsFetchError}}
    @setCustomDateRange={{@controller.setCustomDateRange}}
    @setPeriod={{@controller.setPeriod}}
    @toggleSection={{@controller.toggleSection}}
  />
</template>
