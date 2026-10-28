// Positive type assertions for DButton's `@action` typing: every invocation below
// must compile. Keep this file free of Glint error directives, because one would
// suppress reporting for the rest of the file. Negatives live in
// d-button-action-errors-test.gts.
import { hash } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";

interface Topic {
  id: number;
}

declare const topic: Topic;
declare function archive(topic: Topic): void;
declare function archiveWithEvent(topic: Topic, event: Event): void;
declare function readEvent(param: undefined, event: Event): void;
declare function refresh(): void;

const Positives = <template>
  {{! @actionParam decides the parameter type }}
  <DButton @action={{archive}} @actionParam={{topic}} />

  {{! @forwardEvent adds the triggering event }}
  <DButton
    @action={{archiveWithEvent}}
    @actionParam={{topic}}
    @forwardEvent={{true}}
  />

  {{! The event can be requested without a parameter }}
  <DButton @action={{readEvent}} @forwardEvent={{true}} />

  {{! A handler may ignore what it is given }}
  <DButton @action={{refresh}} />
  <DButton @action={{refresh}} @actionParam={{topic}} />
  <DButton @action={{refresh}} @forwardEvent={{true}} />
  <DButton @action={{archive}} @actionParam={{topic}} @forwardEvent={{true}} />
  <DButton @action={{archive}} @actionParam={{topic}} @forwardEvent={{false}} />

  {{! The object form follows the same rules }}
  <DButton @action={{hash value=archive}} @actionParam={{topic}} />

  {{! No action at all }}
  <DButton @label="topic.create" />
</template>;

export default Positives;
