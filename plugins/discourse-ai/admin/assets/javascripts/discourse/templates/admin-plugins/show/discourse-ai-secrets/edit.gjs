import AiSecretsListEditor from "../../../../components/ai-secrets-list-editor.gjs";

export default <template>
  <AiSecretsListEditor
    @currentSecret={{@controller.model}}
    @secrets={{@controller.allSecrets}}
  />
</template>
