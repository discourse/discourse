import EngagementHeadline from "discourse/admin/components/dashboard/engagement/headline";
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
      {{else if @engagement.headline}}
        <EngagementHeadline
          @headline={{@engagement.headline}}
          @kpis={{@engagement.kpis}}
          @period={{@period}}
        />
      {{/if}}
    </DashboardSection>
  </div>
</template>
