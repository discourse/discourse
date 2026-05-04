import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";

<template>
  <h1>Dashboard</h1>
  <div class="db-main">
    <div class="db-section --kpi">
      <h2 class="db-section__header">April 2026</h2>
      <p class="db-section__intro">Your community grew to 1,100 new members this
        month — and resolved 73% of questions without staff. Most growth came
        from a Hacker News spike on Mar 8–9.</p>
      <div class="db-kpi__wrapper">
        <a class="db-kpi">
          <div class="db-kpi__value">1,100</div>
          <div class="db-kpi__label">New sign-ups</div>
          <div class="db-kpi__delta --pos">+12%</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
        <a class="db-kpi">
          <div class="db-kpi__value-row">
            <div class="db-kpi__value">21%</div>
            <span class="db-kpi__pill --pos">stable</span>
          </div>
          <div class="db-kpi__label">
            DAU / MAU stickiness
            <span
              class="db-section__info"
              aria-label="Daily active users divided by monthly active users. Higher means members come back more often."
              title="Daily active users divided by monthly active users. Higher means members come back more often."
            >{{icon "far-circle-question"}}</span>
          </div>
          <div class="db-kpi__delta --pos">+0.4pts</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
        <a class="db-kpi">
          <div class="db-kpi__value">374</div>
          <div class="db-kpi__label">
            New contributors
            <span
              class="db-section__info"
              aria-label="Members who posted, replied, or reacted for the first time this period."
              title="Members who posted, replied, or reacted for the first time this period."
            >{{icon "far-circle-question"}}</span>
          </div>
          <div class="db-kpi__delta --pos">+6%</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
        <a class="db-kpi">
          <div class="db-kpi__value">73%</div>
          <div class="db-kpi__label">
            Questions resolved
            <span
              class="db-section__info"
              aria-label="Topics in support categories with a marked solution, divided by total topics."
              title="Topics in support categories with a marked solution, divided by total topics."
            >{{icon "far-circle-question"}}</span>
          </div>
          <div class="db-kpi__delta --pos">+1%</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
      </div>
    </div>

    <div class="db-section --reports">
      <h2 class="db-section__header">Reports
        <button class="btn btn-transparent no-text">{{icon "gear"}}</button>
      </h2>
      <div class="db-report__wrapper">

        <div class="db-report__card">
          <div class="db-report__header">
            <a class="db-report__name">Pageviews by type</a>
            <div class="db-report__label">Standard</div>
            <DButton
              @icon="xmark"
              @translatedAriaLabel="Remove"
              class="db-report__remove btn-transparent btn-small"
            />
          </div>
          <div class="db-report__chart">PLACEHOLDER</div>
        </div>

        <div class="db-report__card">
          <div class="db-report__header">
            <a class="db-report__name">New signups</a>
            <div class="db-report__label">Standard</div>
            <DButton
              @icon="xmark"
              @translatedAriaLabel="Remove"
              class="db-report__remove btn-transparent btn-small"
            />
          </div>
          <div class="db-report__chart">PLACEHOLDER</div>
        </div>

        <div class="db-report__card">
          <div class="db-report__header">
            <a class="db-report__name">Active users</a>
            <div class="db-report__label">Standard</div>
            <DButton
              @icon="xmark"
              @translatedAriaLabel="Remove"
              class="db-report__remove btn-transparent btn-small"
            />
          </div>
          <div class="db-report__chart">PLACEHOLDER</div>
        </div>

        <div class="db-report__card">
          <div class="db-report__header">
            <a class="db-report__name">Active users</a>
            <div class="db-report__label">Standard</div>
            <DButton
              @icon="xmark"
              @translatedAriaLabel="Remove"
              class="db-report__remove btn-transparent btn-small"
            />
          </div>
          <div class="db-report__chart">PLACEHOLDER</div>
        </div>

        <button class="db-report__add-report" aria-label="Add report"><span>+
            Add report</span></button>
      </div>
    </div>

  </div>
</template>
