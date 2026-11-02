import Service from "@ember/service";

// Saved in the draft too, so a workflow fired by an autosave can answer the
// composer that saved it.
export const SESSION_ID_FIELD = "workflowsSessionId";

// Identifies one opening of the composer, so a workflow only answers the
// composer it started from: not a later reply to the same topic, nor another
// tab with the same draft.
export default class WorkflowsComposerSession extends Service {
  #ids = new WeakMap();

  idFor(composer) {
    let id = this.#ids.get(composer);

    // Opening the composer resets its draft fields, or restores a saved draft's,
    // so a mismatch means a new opening.
    if (!id || composer.get(SESSION_ID_FIELD) !== id) {
      id = crypto.randomUUID();
      this.#ids.set(composer, id);
      composer.set(SESSION_ID_FIELD, id);
    }

    return id;
  }
}
