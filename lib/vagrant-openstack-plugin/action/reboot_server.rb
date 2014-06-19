require "log4r"

module VagrantPlugins
  module OpenStack
    module Action
      # This reboots a running server, if there is one.
      class RebootServer
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_openstack::action::reboot_server")
        end

        def call(env)
          if env[:machine].id
            env[:ui].info(I18n.t("vagrant_openstack.rebooting_server"))

            # TODO: Validate the fact that we get a server back from the API.
            server = env[:openstack_compute].servers.get(env[:machine].id)
            server.reboot('SOFT')

            env[:ui].info(I18n.t("vagrant_openstack.waiting_for_ssh"))
            while true
              begin
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
              rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH
              end
              sleep 2
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
