import AdminReport from "discourse/admin/components/admin-report";
import BackButton from "discourse/components/back-button";
import routeAction from "discourse/helpers/route-action";

export default <template>
  <BackButton
    @label={{@controller.backLink.label}}
    @query={{@controller.backLink.query}}
    @route={{@controller.backLink.route}}
  />
  <div class="admin-container admin-config-page__main-area">
    <div class="admin-config-area">
      <AdminReport
        @dataSourceName={{@controller.model.type}}
        @filters={{@controller.model}}
        @onRefresh={{routeAction "onParamsChange"}}
        @reportOptions={{@controller.reportOptions}}
        @showDescriptionInTooltip={{false}}
        @showFilteringUI={{true}}
        @showRelatedItems={{@controller.currentUser.admin}}
      />
    </div>
  </div>
</template>
