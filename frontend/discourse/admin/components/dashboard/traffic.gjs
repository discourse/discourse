import DashboardSection from "discourse/admin/components/dashboard/section";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <DashboardSection
    @title={{i18n "admin.dashboard.sections.traffic.title"}}
    @startDate={{@startDate}}
    @endDate={{@endDate}}
  >
    <div class="db-section__subheader">
      <div class="db-section__subintro">
        <h3>712k pageviews this month — up 9%</h3>
        <p>Logged-in traffic is growing steadily. Two spikes on Mar 8–9 drove a
          burst of anonymous visitors who didn't log in, pulling the logged-in
          share down slightly to 38%.</p>
      </div>
      <div class="db-section__metrics">
        <div class="db-section__metric">
          <div class="db-section__metric-number">38%</div>
          <div class="db-section__metric-label">
            Logged-in share
            <span class="db-section__info">{{icon "far-circle-question"}}</span>
          </div>
        </div>
        <div class="db-section__metric">
          <div class="db-section__metric-number">3m 12s</div>
          <div class="db-section__metric-label">Avg. session
          </div>
        </div>
        <div class="db-section__metric">
          <div class="db-section__metric-number">52%</div>
          <div class="db-section__metric-label">Bounce rate
            <span class="db-section__info">{{icon "far-circle-question"}}</span>
          </div>
        </div>
      </div>
    </div>
    <div class="db-section__callout">
      Spikes on Mar 8 and Mar 9 — a Hacker News post linking to the plugin
      release docs drove a surge in anonymous pageviews.
    </div>
    <div class="db-traffic__chart">
      PLACEHOLDER FOR TRAFFIC CHART
    </div>

    <div class="db-section__row">
      <div class="db-section__row-block">
        <div class="db-section__row-block-header">
          <a class="db-section__row-block-title">Top referrers<span
              class="db-link-arrow"
            >{{icon "arrow-right"}}</span></a>
        </div>
        <ul class="db-traffic__list">
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">news.ycombinator.com</span>
            <span class="db-traffic__value">41%
              <span class="db-traffic__count">(34.2k)</span></span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">google.com</span>
            <span class="db-traffic__value">29%
              <span class="db-traffic__count">(24.5k)</span></span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">github.com</span>
            <span class="db-traffic__value">15%
              <span class="db-traffic__count">(12.3k)</span></span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">reddit.com/r/selfhosted</span>
            <span class="db-traffic__value">10%
              <span class="db-traffic__count">(8.0k)</span></span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">duckduckgo.com</span>
            <span class="db-traffic__value">5%
              <span class="db-traffic__count">(4.8k)</span></span>
          </li>
        </ul>
      </div>
      <div class="db-section__row-block">
        <h3 class="db-section__row-block-title">Top countries</h3>
        <ul class="db-traffic__list">
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">🇺🇸 United States</span>
            <span class="db-traffic__value">41%</span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">🇬🇧 United Kingdom</span>
            <span class="db-traffic__value">12%</span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">🇩🇪 Germany</span>
            <span class="db-traffic__value">8%</span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">🇨🇦 Canada</span>
            <span class="db-traffic__value">7%</span>
          </li>
          <li class="db-traffic__list-row">
            <span class="db-traffic__name">🇦🇺 Australia</span>
            <span class="db-traffic__value">4%</span>
          </li>
        </ul>
      </div>
    </div>
  </DashboardSection>
</template>
