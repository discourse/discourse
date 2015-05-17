class SiteCustomizationSerializer < ApplicationSerializer

  attributes :name, :enabled, :created_at, :updated_at,
             :stylesheet, :header, :footer, :top,
             :mobile_stylesheet, :mobile_header, :mobile_footer, :mobile_top,
             :head_tag, :body_tag
end
