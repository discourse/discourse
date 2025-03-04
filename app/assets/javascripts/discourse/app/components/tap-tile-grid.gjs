import Component from "@ember/component";
import { hash } from "@ember/helper";
import { classNames } from "@ember-decorators/component";

@classNames("tap-tile-grid")
export default class TapTileGrid extends Component {<template>{{yield (hash activeTile=this.activeTile)}}</template>
  activeTile = null;
}
