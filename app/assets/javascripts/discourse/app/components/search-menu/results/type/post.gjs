import Blurb from "discourse/components/search-menu/results/blurb";
import iN from "discourse/helpers/i18n";
<template>
  {{iN "search.post_format" @result}}
  <Blurb @result={{@result}} />
</template>
