# name: discourse-edgeryders
# about: Custom discourse functionality for edgeryderse.eu
# version: 0.0.1

register_asset 'stylesheets/consent.scss'
register_asset 'javascripts/bidiweb.build.js'
register_asset 'javascripts/quiz.js'
register_asset 'javascripts/quizlib.1.0.0.min.js'


after_initialize do


  require_dependency 'user_serializer'
  class ::UserSerializer
    attributes :consent_given

    def consent_given
      object.consent_given?
    end
  end


  module ::EdgerydersConsentValidation
    extend ActiveSupport::Concern
    included do

      validate :validate_user_consent

      def validate_user_consent
        errors.add(:base, 'consent required') unless user.consent_given?
      end

    end
  end


  class ::Post
    include EdgerydersConsentValidation
  end


  class ::Topic
    include EdgerydersConsentValidation
  end


  class ::User
    # NOTE: A corresponding 'edgeryders_consent' field must be created in: Admin -> Customize -> User Fields.
    def consent_given?
      UserCustomField.exists?(name: 'edgeryders_consent', value: '1')
    end
  end


end
