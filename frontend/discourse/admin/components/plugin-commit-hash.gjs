import Component from "@glimmer/component";

export default class PluginCommitHash extends Component {
  get shortCommitHash() {
    return this.args.plugin.commitHash?.slice(0, 7);
  }

  <template>
    {{#if @plugin.commitHash}}
      <a
        class="current commit-hash"
        href={{@plugin.commitUrl}}
        rel="noopener noreferrer"
        target="_blank"
        title={{@plugin.commitHash}}
      >{{this.shortCommitHash}}</a>
    {{/if}}
  </template>
}
