import DashboardSection from "discourse/admin/components/dashboard/section";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { i18n } from "discourse-i18n";

<template>
  <DashboardSection
    @title={{i18n "admin.dashboard.sections.engagement.title"}}
    @startDate={{@startDate}}
    @endDate={{@endDate}}
  >
    <div class="db-section__subheader">
      <div class="db-section__subintro">
        <h3>Members are forming a habit of coming back.</h3>
        <p>Stickiness is steady at 21% and new sign-ups are up 9%, but
          daily-engaged members slipped 5% — most active members are
          participating less often than last month.</p>
      </div>
      <div class="db-section__metrics">
        <div class="db-section__metric">
          <div class="db-section__metric-number">38%</div>
          <div class="db-section__metric-label">
            DAU / MAU
          </div>
          <span class="db-pill --pos">stable</span>
        </div>
        <div class="db-section__metric">
          <div class="db-section__metric-number">150</div>
          <div class="db-section__metric-label">Daily visitors
          </div>
          <span class="db-delta --neg">-2%</span>
        </div>
        <div class="db-section__metric">
          <div class="db-section__metric-number">248</div>
          <div class="db-section__metric-label">New sign ups
          </div>
          <span class="db-delta --pos">+12%</span>
        </div>
      </div>
    </div>
    {{! only needed when adding multiple rows }}
    <div class="db-section__row-group">
      <div class="db-section__row">
        <div class="db-section__row-block">
          <div class="db-section__row-block-header">
            <h3 class="db-section__row-block-title">Trust Level Pipeline</h3>
            <span class="db-pill --pos">+72 climbing</span>
          </div>
        </div>
        <div class="db-section__row-block">
          <div class="db-section__row-block-header">
            <h3 class="db-section__row-block-title">Who's contributing?</h3>
          </div>
        </div>
      </div>
      <div class="db-section__row">
        <div class="db-section__row-block"><div
            class="db-section__row-block-header"
          >
            <h3 class="db-section__row-block-title">Activity by category</h3>
            <CategorySelector />
          </div>
          <div class="db-activity">
            //table
          </div>
        </div>
      </div>
    </div>
  </DashboardSection>
</template>
