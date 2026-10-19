import DButton from "discourse/ui-kit/d-button";

const TagInfoButton = <template>
  <DButton
    class="btn-default"
    id="show-tag-info"
    @action={{@toggleInfo}}
    @ariaLabel="tagging.info"
    @ariaPressed={{if @active true false}}
    @icon="circle-info"
    @isLoading={{@loading}}
    @title="tagging.info"
  />
</template>;

export default TagInfoButton;
