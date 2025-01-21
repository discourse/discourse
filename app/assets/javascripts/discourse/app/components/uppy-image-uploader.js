import Component from "@ember/component";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import $ from "jquery";
import discourseComputed from "discourse/lib/decorators";
import { getURLWithCDN } from "discourse/lib/get-url";
import lightbox, {
  cleanupLightboxes,
  setupLightboxes,
} from "discourse/lib/lightbox";
import { authorizesOneOrMoreExtensions } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

@classNames("image-uploader")
export default class UppyImageUploader extends Component {
  @or("notAllowed", "uppyUpload.uploading", "uppyUpload.processing") disabled;

  uppyUpload = null;

  @on("init")
  setupUppyUpload() {
    // The uppyUpload configuration depends on arguments. In classic components like
    // this one, the arguments are not available during field initialization, so we have to
    // defer until init(). When this component is glimmer-ified in future, this can be turned
    // into a simple field initializer.
    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: this.id,
      type: this.type,
      additionalParams: this.additionalParams,
      validateUploadedFilesOptions: { imagesOnly: true },
      uploadDropTargetOptions: () => ({
        target: document.querySelector(`#${this.id} .uploaded-image-preview`),
      }),
      uploadDone: (upload) => {
        this.setProperties({
          imageFilesize: upload.human_filesize,
          imageFilename: upload.original_filename,
          imageWidth: upload.width,
          imageHeight: upload.height,
        });

        // the value of the property used for imageUrl should be set
        // in this callback. this should be done in cases where imageUrl
        // is bound to a computed property of the parent component.
        if (this.onUploadDone) {
          this.onUploadDone(upload);
        } else {
          this.set("imageUrl", upload.url);
        }
      },
    });
  }

  @discourseComputed("id")
  computedId(id) {
    // without a fallback ID this will not be accessible
    return id ? `${id}__input` : `${guidFor(this)}__input`;
  }

  @discourseComputed("siteSettings.enable_experimental_lightbox")
  experimentalLightboxEnabled(experimentalLightboxEnabled) {
    return experimentalLightboxEnabled;
  }

  @discourseComputed("disabled", "notAllowed")
  disabledReason(disabled, notAllowed) {
    if (disabled && notAllowed) {
      return i18n("post.errors.no_uploads_authorized");
    }
  }

  @discourseComputed(
    "currentUser.staff",
    "siteSettings.{authorized_extensions,authorized_extensions_for_staff}"
  )
  notAllowed() {
    return !authorizesOneOrMoreExtensions(
      this.currentUser?.staff,
      this.siteSettings
    );
  }

  @discourseComputed("imageUrl", "placeholderUrl")
  showingPlaceholder(imageUrl, placeholderUrl) {
    return !imageUrl && placeholderUrl;
  }

  @discourseComputed("placeholderUrl")
  placeholderStyle(url) {
    if (isEmpty(url)) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image: url(${url})`);
  }

  @discourseComputed("imageUrl")
  imageCDNURL(url) {
    if (isEmpty(url)) {
      return htmlSafe("");
    }

    return getURLWithCDN(url);
  }

  @discourseComputed("imageCDNURL")
  backgroundStyle(url) {
    return htmlSafe(`background-image: url(${url})`);
  }

  @discourseComputed("imageUrl")
  imageBaseName(imageUrl) {
    if (isEmpty(imageUrl)) {
      return;
    }
    return imageUrl.split("/").slice(-1)[0];
  }

  @on("didRender")
  _applyLightbox() {
    if (this.experimentalLightboxEnabled) {
      setupLightboxes({
        container: this.element,
        selector: ".lightbox",
      });
    } else {
      next(() => lightbox(this.element, this.siteSettings));
    }
  }

  @on("willDestroyElement")
  _closeOnRemoval() {
    if (this.experimentalLightboxEnabled) {
      cleanupLightboxes();
    } else {
      if ($.magnificPopup?.instance) {
        $.magnificPopup.instance.close();
      }
    }
  }

  @action
  toggleLightbox() {
    $(this.element.querySelector("a.lightbox"))?.magnificPopup("open");
  }

  @action
  trash() {
    // the value of the property used for imageUrl should be cleared
    // in this callback. this should be done in cases where imageUrl
    // is bound to a computed property of the parent component.
    if (this.onUploadDeleted) {
      this.onUploadDeleted();
    } else {
      this.setProperties({ imageUrl: null });
    }
  }

  @action
  handleKeyboardActivation(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault(); // avoid space scrolling the page
      const input = document.getElementById(this.computedId);
      if (input && !this.disabled) {
        input.click();
      }
    }
  }
}
