import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

const callbacks = [
  ({ composerContainerState }) => {
    if (composerContainerState.targetRecipients) {
      composerContainerState.setState({
        shouldDisplayActionTitle: false,
        shouldDisplayFields: false,
        bodyClassNames: "test",
      });
    }
  },
];

class ComposerContainerState {
  @tracked shouldDisplayActionTitle = true;
  @tracked shouldDisplayFields = true;
  @tracked bodyClassNames = "";

  constructor({ composer }) {
    this.composer = composer;
  }

  targetRecipients() {
    return true;
    return this.composer.targetRecipients;
  }

  setState({ shouldDisplayActionTitle, shouldDisplayFields, bodyClassNames }) {
    this.shouldDisplayActionTitle = shouldDisplayActionTitle;
    this.shouldDisplayFields = shouldDisplayFields;
    this.bodyClassNames = bodyClassNames;
  }
}

export default class ComposerContainer extends Component {
  @service composer;
  @service site;

  composerContainerState = new ComposerContainerState(this.composer);

  constructor() {
    super(...arguments);

    this.composer.onStateChange(() =>
      this.#triggerComposerStateChangeCallbacks()
    );
  }

  #triggerComposerStateChangeCallbacks() {
    callbacks.forEach((callback) => {
      callback({
        composerContainerState: this.composerContainerState,
      });
    });
  }
}
