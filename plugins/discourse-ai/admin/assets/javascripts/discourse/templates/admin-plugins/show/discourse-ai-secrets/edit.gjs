import AiSecretsListEditor from "../../../../../discourse/components/ai-secrets-list-editor";

export default <template>
  <AiSecretsListEditor
    @secrets={{@controller.allSecrets}}
    @currentSecret={{@controller.model}}
  />
</template>
