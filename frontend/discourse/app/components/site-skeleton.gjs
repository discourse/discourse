import dIcon from "discourse/ui-kit/helpers/d-icon";

// Decorative, inert loading skeleton — content is placeholder bars, not text.
<template>
  <div class="site-skeleton" aria-hidden="true">
    <div class="site-skeleton__header">
      <div class="site-skeleton__brand">
        <span class="site-skeleton__menu">
          {{dIcon "bars"}}
        </span>
        <span class="site-skeleton__bar --brand"></span>
      </div>
      <span class="site-skeleton__chat">
        {{dIcon "comment"}}
      </span>
      <span class="site-skeleton__avatar"></span>
    </div>

    <div class="site-skeleton__body">
      <aside class="site-skeleton__sidebar">
        <div class="site-skeleton__new-topic"></div>

        <div class="site-skeleton__nav-item --active">
          <span class="site-skeleton__nav-icon">
            {{dIcon "layer-group"}}
          </span>
          <span class="site-skeleton__bar --accent --md"></span>
        </div>
        <div class="site-skeleton__nav-item">
          <span class="site-skeleton__nav-icon">
            {{dIcon "user"}}
          </span>
          <span class="site-skeleton__bar --lg"></span>
        </div>
        <div class="site-skeleton__nav-item">
          <span class="site-skeleton__nav-icon">
            {{dIcon "inbox"}}
          </span>
          <span class="site-skeleton__bar --md"></span>
        </div>
        <div class="site-skeleton__nav-item">
          <span class="site-skeleton__nav-icon">
            {{dIcon "flag"}}
          </span>
          <span class="site-skeleton__bar --sm"></span>
        </div>
        <div class="site-skeleton__nav-item">
          <span class="site-skeleton__nav-icon">
            {{dIcon "wrench"}}
          </span>
          <span class="site-skeleton__bar --md"></span>
        </div>
        <div class="site-skeleton__nav-item">
          <span class="site-skeleton__nav-icon">
            {{dIcon "paper-plane"}}
          </span>
          <span class="site-skeleton__bar --sm"></span>
        </div>

        <div class="site-skeleton__sidebar-section">
          <div class="site-skeleton__sidebar-title">
            <span class="site-skeleton__bar --title"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__category-dot --blue"></span>
            <span class="site-skeleton__bar --md"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__category-dot --light-blue"></span>
            <span class="site-skeleton__bar --lg"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__category-dot --staff"></span>
            <span class="site-skeleton__bar --sm"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__nav-icon">
              {{dIcon "list"}}
            </span>
            <span class="site-skeleton__bar --md"></span>
          </div>
        </div>

        <div class="site-skeleton__sidebar-section">
          <div class="site-skeleton__category">
            <span class="site-skeleton__nav-icon">
              {{dIcon "magnifying-glass"}}
            </span>
            <span class="site-skeleton__bar --md"></span>
          </div>
        </div>

        <div class="site-skeleton__sidebar-section">
          <div class="site-skeleton__sidebar-title">
            <span class="site-skeleton__bar --title"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__channel --blue"></span>
            <span class="site-skeleton__bar --md"></span>
          </div>
          <div class="site-skeleton__category">
            <span class="site-skeleton__channel --red"></span>
            <span class="site-skeleton__bar --sm"></span>
          </div>
        </div>
      </aside>

      <main class="site-skeleton__content">
        <section class="site-skeleton__card">
          <div class="site-skeleton__welcome-row">
            <div class="site-skeleton__welcome-greeting">
              <span class="site-skeleton__bar --heading --lg"></span>
              <span class="site-skeleton__bar --heading --md"></span>
            </div>
            <div class="site-skeleton__search">
              <span class="site-skeleton__search-icon">
                {{dIcon "magnifying-glass"}}
              </span>
              <span class="site-skeleton__bar --sm"></span>
              <span class="site-skeleton__search-icon --filters">
                {{dIcon "sliders"}}
              </span>
            </div>
          </div>

          <div class="site-skeleton__tabs">
            <span class="--active">
              <span class="site-skeleton__bar --accent --sm"></span>
            </span>
            <span>
              <span class="site-skeleton__bar --sm"></span>
            </span>
            <span>
              <span class="site-skeleton__bar --sm"></span>
            </span>
            <button type="button" tabindex="-1"></button>
          </div>

          <div class="site-skeleton__topic-list">
            <div class="site-skeleton__topic">
              <span class="site-skeleton__topic-avatar --system"></span>
              <div class="site-skeleton__topic-main">
                <span class="site-skeleton__bar --sm"></span>
                <span class="site-skeleton__bar --strong --lg"></span>
                <div class="site-skeleton__topic-excerpt">
                  <span class="site-skeleton__bar --full"></span>
                  <span class="site-skeleton__bar --full"></span>
                  <span class="site-skeleton__bar --lg"></span>
                </div>
                <span class="site-skeleton__topic-tag"></span>
              </div>
              <span class="site-skeleton__topic-pin"></span>
            </div>
            <div class="site-skeleton__topic">
              <span class="site-skeleton__topic-avatar --system"></span>
              <div class="site-skeleton__topic-main">
                <span class="site-skeleton__bar --sm"></span>
                <span class="site-skeleton__bar --strong --md"></span>
                <div class="site-skeleton__topic-excerpt">
                  <span class="site-skeleton__bar --full"></span>
                  <span class="site-skeleton__bar --md"></span>
                </div>
                <span class="site-skeleton__topic-tag --staff"></span>
              </div>
            </div>
            <div class="site-skeleton__topic">
              <span class="site-skeleton__topic-avatar --system"></span>
              <div class="site-skeleton__topic-main">
                <span class="site-skeleton__bar --sm"></span>
                <span class="site-skeleton__bar --strong --lg"></span>
                <div class="site-skeleton__topic-excerpt">
                  <span class="site-skeleton__bar --full"></span>
                  <span class="site-skeleton__bar --lg"></span>
                </div>
                <span class="site-skeleton__topic-tag --staff"></span>
              </div>
            </div>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
