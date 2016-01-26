class RebakeHtmlCustomizations < ActiveRecord::Migration
  def change
    execute "UPDATE site_customizations SET body_tag_baked = NULL,
                                            head_tag_baked = NULL,
                                            header_baked = NULL,
                                            mobile_header_baked = NULL,
                                            footer_baked = NULL,
                                            mobile_footer_baked = NULL"
  end
end
