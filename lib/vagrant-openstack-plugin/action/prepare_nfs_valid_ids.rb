module VagrantPlugins
  module OpenStack
    module Action
      class PrepareNFSValidIds
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          servers = []
          env[:openstack_compute].list_servers.body['servers'].each do |server|
            servers.push(server['id'])
          end

          env[:nfs_valid_ids] = servers
          @app.call(env)
        end
      end
    end
  end
end
