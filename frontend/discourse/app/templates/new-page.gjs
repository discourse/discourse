import icon from "discourse/helpers/d-icon";

<template>
  <h1>Reporting blocks</h1>
  <div class="db-section">

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
</template>
