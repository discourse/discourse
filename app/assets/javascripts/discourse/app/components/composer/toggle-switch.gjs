import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";

const ComposerToggleSwitch = <template>
  {{! template-lint-disable no-redundant-role }}
  <button
    class="{{concatClass
        'composer-toggle-switch'
        (if @state '--rte' '--markdown')
      }}"
    type="button"
    role="switch"
    aria-pressed={{if @state "true" "false"}}
    ...attributes
  >
    {{! template-lint-enable no-redundant-role }}

    <span class="composer-toggle-switch__slider" focusable="false">
      <span
        class={{concatClass
          "composer-toggle-switch__left-icon"
          (unless @state "--active")
        }}
        aria-hidden="true"
        focusable="false"
      >{{icon "fab-markdown"}}</span>
      <span
        class={{concatClass
          "composer-toggle-switch__right-icon"
          (if @state "--active")
        }}
        aria-hidden="true"
        focusable="false"
      >{{icon "a"}}</span>
    </span>
  </button>
</template>;

export default ComposerToggleSwitch;
