/* global base64js:true */
import ModalFunctionality from "discourse/mixins/modal-functionality";

// model for this controller is user.js.es6
export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,

  onShow() {
    // clear properties every time because the controller is a singleton
    this.setProperties({
      errorMessage: null,
      loading: true,
      securityKeyName: I18n.t("user.second_factor.security_key.default_name")
    });

    this.model
      .requestSecurityKeyChallenge()
      .then(response => {
        if (response.error) {
          this.set('errorMessage', response.error);
          return;
        }

        this.setProperties({
          errorMessage: null,
          loading: false,
          challenge: response.challenge,
          relayingParty: {
            id: response.rp_id,
            name: response.rp_name
          },
          supported_algoriths: response.supported_algoriths,
          user_secure_id: response.user_secure_id
        });
      })
      .catch(error => {
        this.send("closeModal");
        this.onError(error);
      })
      .finally(() => this.set("loading", false));
  },

  actions: {
    registerSecurityKey() {
      const publicKeyCredentialCreationOptions = {
        challenge: Uint8Array.from(
          this.get('challenge'), c => c.charCodeAt(0)),
        rp: {
          name: this.get('relayingParty.name'),
          id: this.get('relayingParty.id')
        },
        user: {
          id: Uint8Array.from(
            this.get('user_secure_id'), c => c.charCodeAt(0)),
          displayName: this.model.username_lower,
          name: this.model.username_lower
        },
        pubKeyCredParams: this.get('supported_algoriths').map(alg => { return { type: 'public-key', alg: alg }; }),
        timeout: 20000,
        attestation: 'none'
      };

      navigator.credentials.create({
        publicKey: publicKeyCredentialCreationOptions
      }).then((credential) => {
        let serverData = {
          id: credential.id,
          rawId: base64js.fromByteArray(new Uint8Array(credential.rawId)),
          type: credential.type,
          attestation: base64js.fromByteArray(new Uint8Array(credential.response.attestationObject)),
          clientData: base64js.fromByteArray(new Uint8Array(credential.response.clientDataJSON)),
          name: this.get('securityKeyName')
        };

        this.model.registerSecurityKey(serverData).then(() => {
          this.markDirty();
          this.set("errorMessage", null);
          this.send("closeModal");
        });
      }, (err) => {
        if (err.name === 'NotAllowedError') {
          return this.set("errorMessage", I18n.t('user.second_factor.security_key.not_allowed_error'));
        }
        this.set("errorMessage", err.message);
      });
    }
  }
});
