import GroupList from "discourse/components/group-list";
import PluginOutlet from "discourse/components/plugin-outlet";

<template>
  <GroupList
    @groups={{@model.groups}}
    @type={{@controller.type}}
    @filter={{@controller.filter}}
    @onTypeChanged={{@controller.onTypeChanged}}
    @onFilterChanged={{@controller.onFilterChanged}}
  />

  <PluginOutlet @name="after-groups-index-container" @connectorTagName="div" />
</template>
