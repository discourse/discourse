class Chef
  class Provider
    class WindowsFeature
      module Base

        def action_install
          unless installed?
            install_feature(@new_resource.feature_name)
            @new_resource.updated_by_last_action(true)
            Chef::Log.info("#{@new_resource} installed feature")
          else
            Chef::Log.debug("#{@new_resource} is already installed - nothing to do")
          end
        end

        def action_remove
          if installed?
            remove_feature(@new_resource.feature_name)
            @new_resource.updated_by_last_action(true)
            Chef::Log.info("#{@new_resource} removed")
          else
            Chef::Log.debug("#{@new_resource} feature does not exist - nothing to do")
          end
        end

        def install_feature(name)
          raise Chef::Exceptions::UnsupportedAction, "#{self.to_s} does not support :install"
        end

        def remove_feature(name)
          raise Chef::Exceptions::UnsupportedAction, "#{self.to_s} does not support :remove"
        end

        def installed?
          raise Chef::Exceptions::Override, "You must override installed? in #{self.to_s}"
        end
      end
    end
  end
end
      