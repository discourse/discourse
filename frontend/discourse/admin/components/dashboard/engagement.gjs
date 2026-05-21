import EngagementHeadline from "discourse/admin/components/dashboard/engagement/headline";
import TrustLevelPipeline from "discourse/admin/components/dashboard/engagement/trust-level-pipeline";
import WhosPosting from "discourse/admin/components/dashboard/engagement/whos-posting";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { i18n } from "discourse-i18n";

<template>
  <div class="db-engagement">
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.engagement.title"}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
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
                <TrustLevelPipeline
                  @data={{@engagement.trust_level_pipeline}}
                />
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
          <div class="db-section__row">
            <div class="db-section__row-block">
              <div class="db-section__row-block-header">
                <h3 class="db-section__row-block-title">
                  {{i18n
                    "admin.dashboard.sections.engagement.activity_by_category.title"
                  }}
                </h3>
              </div>
            </div>
          </div>
        </div>
      {{/if}}
    </DashboardSection>
  </div>
</template>
