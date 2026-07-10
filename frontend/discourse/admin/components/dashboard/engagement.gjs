import ActivityByCategory from "discourse/admin/components/dashboard/engagement/activity-by-category";
import EngagementHeadline from "discourse/admin/components/dashboard/engagement/headline";
import TrustLevelPipeline from "discourse/admin/components/dashboard/engagement/trust-level-pipeline";
import WhosPosting from "discourse/admin/components/dashboard/engagement/whos-posting";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { i18n } from "discourse-i18n";

export default <template>
  <DashboardSection
    @title={{i18n "admin.dashboard.sections.engagement.title"}}
    @startDate={{@startDate}}
    @endDate={{@endDate}}
    ...attributes
  >
    {{#if @fetchError}}
      <div class="db-section__error" role="alert">
        {{i18n "admin.dashboard.sections.engagement.fetch_error"}}
      </div>
    {{else}}
      {{#if @engagement.headline}}
        <EngagementHeadline
          @headline={{@engagement.headline}}
          @kpis={{@engagement.kpis}}
          @period={{@period}}
        />
      {{/if}}

      <div class="db-section__row-group">
        <div class="db-section__row">
          <div class="db-section__row-block">
            {{#if @engagement.trust_level_pipeline}}
              <TrustLevelPipeline @data={{@engagement.trust_level_pipeline}} />
            {{/if}}
          </div>
          <div class="db-section__row-block">
            <WhosPosting
              @posters={{@engagement.posters}}
              @startDate={{@startDate}}
              @endDate={{@endDate}}
            />
          </div>
        </div>
        {{#if @engagement.activity_by_category}}
          <div class="db-section__row">
            <div class="db-section__row-block">
              <ActivityByCategory
                @activity={{@engagement.activity_by_category}}
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </DashboardSection>
</template>
