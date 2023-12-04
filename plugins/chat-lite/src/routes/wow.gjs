import Route from "discourse-plugin/routing/route";

export default class WowRoute extends Route {
  async load() {
    const latest = await fetch("/latest.json");
    const parsed = await latest.json();
    return parsed.topic_list.topics.length;
  }

  <template>
    {{#if this.isLoading}}
      loading...
    {{else}}
      Wow, there are a total of
      {{this.model}}
      topics. Isn't it amazing?
    {{/if}}
  </template>
}
