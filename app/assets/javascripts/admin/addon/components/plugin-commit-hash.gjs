import Component from "@glimmer/component";

export default class PluginCommitHash extends Component {
  get shortCommitHash() {
    return this.args.plugin.commitHash?.slice(0, 7);
  }

  <template>
    {{#if @plugin.commitHash}}
      <a
        href={{@plugin.commitUrl}}
        target="_blank"
        rel="noopener noreferrer"
        class="current commit-hash"
        title={{@plugin.commitHash}}
      >{{this.shortCommitHash}}</a>
    {{/if}}
  </template>
}
