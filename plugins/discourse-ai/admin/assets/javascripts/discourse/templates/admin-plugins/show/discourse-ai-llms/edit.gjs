import AiLlmsListEditor from "../../../../components/ai-llms-list-editor.gjs";

export default <template>
  <AiLlmsListEditor
    @currentLlm={{@controller.model}}
    @llms={{@controller.allLlms}}
  />
</template>
