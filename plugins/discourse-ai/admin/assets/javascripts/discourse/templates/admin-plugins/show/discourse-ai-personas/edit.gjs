import AiPersonaListEditor from "../../../../components/ai-persona-list-editor";

export default <template>
  <AiPersonaListEditor
    @personas={{@controller.allPersonas}}
    @currentPersona={{@controller.model}}
  />
</template>
