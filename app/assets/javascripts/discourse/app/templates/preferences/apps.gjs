import PluginOutlet from "discourse/components/plugin-outlet";
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import lazyHash from "discourse/helpers/lazy-hash";

<template>
  <UserApiKeys @model={{@model}} />

  <span>
    <PluginOutlet
      @name="user-preferences-apps"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>
</template>
