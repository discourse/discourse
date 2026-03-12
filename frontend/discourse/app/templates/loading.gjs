import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import loadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default <template>
  {{loadingSpinner}}
  {{hideApplicationFooter}}
</template>
