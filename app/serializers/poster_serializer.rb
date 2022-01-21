# frozen_string_literal: true

class PosterSerializer < BasicUserSerializer
  include UserPrimaryGroupMixin

  attributes :external_id

  def external_id
    object.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_discourse_connect_external_id_serializers?
  end
end
