import DButton from "discourse/ui-kit/d-button";

const TagInfoButton = <template>
  <DButton
    @icon="circle-info"
    @ariaLabel="tagging.info"
    @title="tagging.info"
    @action={{@toggleInfo}}
    @ariaPressed={{if @active true false}}
    @isLoading={{@loading}}
    id="show-tag-info"
    class="btn-default"
  />
</template>;

export default TagInfoButton;
