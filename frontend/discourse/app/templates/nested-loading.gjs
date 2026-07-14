import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default <template>
  {{dLoadingSpinner}}
  {{hideApplicationFooter}}
</template>
