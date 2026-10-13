import AiSecretsListEditor from "../../../../components/ai-secrets-list-editor";

export default <template>
  <AiSecretsListEditor
    @currentSecret={{@controller.model}}
    @secrets={{@controller.allSecrets}}
  />
</template>
