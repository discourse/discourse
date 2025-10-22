import RouteTemplate from "ember-route-template";
import AiPersonaListEditor from "../../../../../discourse/components/ai-persona-list-editor";

export default RouteTemplate(
  <template>
    <AiPersonaListEditor
      @personas={{@controller.allPersonas}}
      @currentPersona={{@controller.model}}
    />
  </template>
);
