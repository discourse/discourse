import Component from "@glimmer/component";

export default class PluginCommitHash extends Component {
  get shortCommitHash() {
    return this.args.plugin.commit_hash?.slice(0, 7);
  }
}
