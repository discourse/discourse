import Component from "@glimmer/component";
import { alias } from "@ember/object/computed";

export default class PluginCommitHash extends Component {
  @alias("args.plugin.commit_url") commitUrl;

  get shortCommitHash() {
    return this.commitHash?.slice(0, 7);
  }

  get commitHash() {
    return this.args.plugin.commit_hash;
  }
}
