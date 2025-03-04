import dIcon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import or from "truth-helpers/helpers/or";
<template>{{dIcon "tag"}}
{{discourseTag (or @result.id @result) tagName="span"}}</template>