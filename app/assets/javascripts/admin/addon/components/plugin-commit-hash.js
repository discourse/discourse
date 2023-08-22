import Component from "@glimmer/component";

export default class PluginCommitHash extends Component {
  get shortCommitHash() {
    return this.commitHash?.slice(0, 7);
  }

  get commitHash() {
    return this.args.plugin.commit_hash;
  }
}
