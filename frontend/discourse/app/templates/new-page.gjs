import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import CategorySelector from "discourse/select-kit/components/category-selector";

<template>
  <h1>Dashboard</h1>
  <div class="db-main">
    <div class="db-section --kpi">
      <h2 class="db-section__header">April 2026</h2>
      <p class="db-section__intro">Your community grew to 1,100 new members this
        month — and resolved 73% of questions without staff. Most growth came
        from a Hacker News spike on Mar 8–9.</p>
      <div class="db-section__wrapper">
        <a class="db-kpi">
          <div class="db-kpi__value">1,100</div>
          <div class="db-kpi__label">New sign-ups</div>
          <div class="db-delta --pos">+12%</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
        <a class="db-kpi">
          <div class="db-kpi__value-row">
            <div class="db-kpi__value">21%</div>
            <span class="db-pill --pos">stable</span>
          </div>
          <div class="db-kpi__label">
            DAU / MAU stickiness
            <span
              class="db-section__info"
              aria-label="Daily active users divided by monthly active users. Higher means members come back more often."
              title="Daily active users divided by monthly active users. Higher means members come back more often."
            >{{icon "far-circle-question"}}</span>
          </div>
          <div class="db-delta --pos">+0.4pts</div>
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
          <div class="db-delta --pos">+6%</div>
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
          <div class="db-delta --pos">+1%</div>
          <span class="db-kpi__arrow">{{icon "arrow-right"}}</span>
        </a>
      </div>
    </div>

    <div class="db-section --reports">
      <h2 class="db-section__header">Reports
        <button class="btn btn-transparent no-text">{{icon "gear"}}</button>
      </h2>
      <div class="db-section__wrapper">

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
            <div class="db-report__label --data-explorer">Data Explorer</div>
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

        <button class="db-report__add-report" aria-label="Add report"><span
          >{{icon "plus"}}
            Add report</span></button>
      </div>

      <aside class="db-upgrade-banner">
        <p>Upgrade to pin Data Explorer queries as charts to track anything
          specific to your community.</p>
        <DButton @display="link" @suffixIcon="arrow-right">Upgrade</DButton>
      </aside>

    </div>

    <div class="db-section --traffic">
      <h2 class="db-section__header">Site traffic</h2>
      <div class="db-section__wrapper">
        <div class="db-section__subheader">
          <div class="db-section__subintro">
            <h3>712k pageviews this month — up 9%</h3>
            <p>Logged-in traffic is growing steadily. Two spikes on Mar 8–9
              drove a burst of anonymous visitors who didn't log in, pulling the
              logged-in share down slightly to 38%.</p>
          </div>
          <div class="db-section__metrics">
            <div class="db-section__metric">
              <div class="db-section__metric-number">38%</div>
              <div class="db-section__metric-label">
                Logged-in share
                <span class="db-section__info">{{icon
                    "far-circle-question"
                  }}</span>
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
                <span class="db-section__info">{{icon
                    "far-circle-question"
                  }}</span>
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
            <h3 class="db-section__row-block-title">Top referrers</h3>
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
      </div>
    </div>

    <div class="db-section --engagement">
      <h2 class="db-section__header">Engagement</h2>
      <div class="db-section__wrapper">
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
        <div class="db-section__subwrapper">
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
          <div class="db-section__row --single">
            <div class="db-section__row-block-header">
              <h3 class="db-section__row-block-title">Activity by category</h3>
              <CategorySelector />
            </div>
            <div class="db-activity">
              //table
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
