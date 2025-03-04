import iN from "discourse/helpers/i18n";
import Blurb from "discourse/components/search-menu/results/blurb";
<template>{{iN "search.post_format" @result}}
<Blurb @result={{@result}} /></template>