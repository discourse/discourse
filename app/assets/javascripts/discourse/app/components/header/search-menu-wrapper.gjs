import SearchMenuPanel from "../search-menu-panel";

<template>
  <div class="search-menu glimmer-search-menu" aria-live="polite" ...attributes>
    <SearchMenuPanel
      @searchInputId={{@searchInputId}}
      @closeSearchMenu={{@closeSearchMenu}}
    />
  </div>
</template>
