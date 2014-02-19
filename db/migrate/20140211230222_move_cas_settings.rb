class MoveCasSettings < ActiveRecord::Migration
  def change
    #As part of removing the build in CAS authentication we should
    #convert the data over to be used by the plugin.
    cas_hostname = SiteSetting.where(name: 'cas_hostname').first
    cas_sso_hostname = SiteSetting.where(name: 'cas_sso_hostname').first
    if cas_hostname  && ! cas_sso_hostname
      #convert the setting over for use by the plugin
      cas_hostname.update_attribute(:name, 'cas_sso_hostname')
    elsif cas_hostname  && cas_sso_hostname
      #copy the setting over for use by the plugin and delete the original setting
      cas_sso_hostname.update_attribute(:value,cas_hostname.value)
      cas_hostname.destroy
    end

    cas_domainname = SiteSetting.where(name: 'cas_domainname').first
    cas_sso_email_domain = SiteSetting.where(name: 'cas_sso_email_domain').first
    if cas_domainname  && ! cas_sso_email_domain
      #convert the setting over for use by the plugin
      cas_domainname.update_attribute(:name, 'cas_sso_email_domain')
    elsif cas_domainname  && cas_sso_email_domain
      #copy the setting over for use by the plugin and delete the original setting
      cas_sso_email_domain.update_attribute(:value,cas_domainname.value)
      cas_domainname.destroy
    end

    cas_logins = SiteSetting.where(name: 'cas_logins').first
    if cas_logins
      cas_logins.destroy
    end

    #remove the unused table
   drop_table :cas_user_infos

  end
end
