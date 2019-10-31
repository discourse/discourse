# frozen_string_literal: true

class IncomingEmailSerializer < ApplicationSerializer

  attributes :id,
             :created_at,
             :from_address,
             :to_addresses,
             :cc_addresses,
             :subject,
             :error,
             :post_url

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def post_url
    object.post.url
  end

  def include_post_url?
    object.post.present?
  end

  def to_addresses
    return if object.to_addresses.blank?
    object.to_addresses.split(";")
  end

  def cc_addresses
    return if object.cc_addresses.blank?
    object.cc_addresses.split(";")
  end

  def error
    @object.error.presence || I18n.t("emails.incoming.unrecognized_error")
  end

end
