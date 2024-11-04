import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";

const ComposerToggleSwitch = <template>
  <div class="composer-toggle-switch">
    <label class="composer-toggle-switch__label">
      {{! template-lint-disable no-redundant-role }}
      <button
        class="composer-toggle-switch__checkbox"
        type="button"
        role="switch"
        aria-checked={{if @state "true" "false"}}
        ...attributes
      ></button>
      {{! template-lint-enable no-redundant-role }}

      <span class="composer-toggle-switch__checkbox-slider">
        <span
          class={{concatClass
            "composer-toggle-switch__left-icon"
            (unless @state "--active")
          }}
        >{{icon "fab-markdown"}}</span>
        <span
          class={{concatClass
            "composer-toggle-switch__right-icon"
            (if @state "--active")
          }}
        >{{icon "a"}}</span>
      </span>
    </label>
  </div>
</template>;

export default ComposerToggleSwitch;
