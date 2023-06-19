import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default class PluginCommitHash extends Component {
  @discourseComputed("plugin.commit_hash")
  shortCommitHash(commitHash) {
    return commitHash?.slice(0, 7);
  }
}
