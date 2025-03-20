import SearchMenuPanel from "../search-menu-panel";

<template>
  <div class="search-menu glimmer-search-menu" aria-live="polite" ...attributes>
    <SearchMenuPanel @closeSearchMenu={{@closeSearchMenu}} />
  </div>
</template>
